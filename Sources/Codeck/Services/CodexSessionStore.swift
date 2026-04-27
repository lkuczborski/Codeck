import Foundation
import SwiftUI

enum CodexSessionState: String, Hashable {
  case idle
  case running
  case completed
  case failed
  case stopped
}

struct CodexSessionOutput: Hashable {
  var state: CodexSessionState
  var text: String
  var standardOutput: String
  var standardError: String

  init(
    state: CodexSessionState,
    text: String,
    standardOutput: String = "",
    standardError: String = ""
  ) {
    self.state = state
    self.text = text
    self.standardOutput = standardOutput
    self.standardError = standardError
  }
}

@MainActor
final class CodexSessionStore: ObservableObject {
  @Published private(set) var outputs: [String: CodexSessionOutput] = [:]
  @Published private(set) var runningIDs: Set<String> = []

  private var processes: [String: Process] = [:]
  private var outputPipes: [String: Pipe] = [:]
  private var errorPipes: [String: Pipe] = [:]
  private var inputPipes: [String: Pipe] = [:]
  private var outputLineBuffers: [String: String] = [:]
  private var appServerContexts: [String: AppServerContext] = [:]

  func output(for blockID: String) -> CodexSessionOutput {
    outputs[blockID] ?? CodexSessionOutput(state: .idle, text: "")
  }

  func run(_ block: CodexBlock, settings: DeckCodexSettings = .default, workingDirectory: URL?) {
    stop(block.id)

    let process = CodexSessionRunner.makeProcess(for: block, settings: settings, workingDirectory: workingDirectory)
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    let inputPipe = Pipe()

    process.standardOutput = outputPipe
    process.standardError = errorPipe
    process.standardInput = inputPipe

    outputs[block.id] = CodexSessionOutput(state: .running, text: "")
    runningIDs.insert(block.id)
    processes[block.id] = process
    outputPipes[block.id] = outputPipe
    errorPipes[block.id] = errorPipe
    inputPipes[block.id] = inputPipe
    appServerContexts[block.id] = AppServerContext(
      block: block,
      settings: settings,
      workingDirectory: workingDirectory
    )

    outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      let text = String(decoding: data, as: UTF8.self)
      Task { @MainActor in
        self?.append(text, to: block.id, stream: .standardOutput)
      }
    }

    errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      let text = String(decoding: data, as: UTF8.self)
      Task { @MainActor in
        self?.append(text, to: block.id, stream: .standardError)
      }
    }

    process.terminationHandler = { [weak self] process in
      Task { @MainActor in
        self?.finish(blockID: block.id, status: process.terminationStatus)
      }
    }

    do {
      try process.run()
      sendInitialize(to: block.id)
    } catch {
      outputs[block.id] = CodexSessionOutput(
        state: .failed,
        text: "Could not start Codex: \(error.localizedDescription)",
        standardError: "Could not start Codex: \(error.localizedDescription)"
      )
      cleanup(blockID: block.id)
    }
  }

  func runAll(_ blocks: [CodexBlock], settings: DeckCodexSettings = .default, workingDirectory: URL?) {
    for block in blocks {
      run(block, settings: settings, workingDirectory: workingDirectory)
    }
  }

  func stop(_ blockID: String) {
    guard let process = processes[blockID] else { return }
    process.terminate()
    var output = output(for: blockID)
    output.state = .stopped
    output.text += "\nStopped."
    outputs[blockID] = output
    cleanup(blockID: blockID)
  }

  func stopAll() {
    for blockID in Array(processes.keys) {
      stop(blockID)
    }
  }

  deinit {
    for process in processes.values {
      process.terminate()
    }
  }

  private enum SessionStream {
    case standardOutput
    case standardError
  }

  private struct AppServerContext {
    let block: CodexBlock
    let settings: DeckCodexSettings
    let workingDirectory: URL?
    let initializeRequestID: String
    let threadStartRequestID: String
    let turnStartRequestID: String
    var threadID: String?
    var turnID: String?

    init(block: CodexBlock, settings: DeckCodexSettings, workingDirectory: URL?) {
      self.block = block
      self.settings = settings
      self.workingDirectory = workingDirectory
      self.initializeRequestID = "\(block.id)-initialize"
      self.threadStartRequestID = "\(block.id)-thread-start"
      self.turnStartRequestID = "\(block.id)-turn-start"
    }
  }

  private func append(_ text: String, to blockID: String, stream: SessionStream) {
    switch stream {
    case .standardOutput:
      appendAppServerLines(text, to: blockID)
    case .standardError:
      appendDiagnosticText(text, to: blockID)
    }
  }

  private func appendDiagnosticText(_ text: String, to blockID: String) {
    var output = output(for: blockID)
    output.text += text
    output.standardError += text
    outputs[blockID] = output
  }

  private func appendAppServerLines(_ text: String, to blockID: String) {
    var buffer = outputLineBuffers[blockID, default: ""]
    buffer += text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    let lines = buffer.components(separatedBy: "\n")
    outputLineBuffers[blockID] = lines.last ?? ""

    for line in lines.dropLast() {
      handleAppServerLine(line, for: blockID)
    }
  }

  private func handleAppServerLine(_ line: String, for blockID: String) {
    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedLine.isEmpty else { return }

    guard let object = CodexJSONEventParser.object(from: trimmedLine) else {
      return
    }

    if let errorMessage = CodexJSONEventParser.errorMessage(from: object) {
      fail(blockID: blockID, message: errorMessage)
      return
    }

    if let delta = CodexJSONEventParser.assistantDelta(from: object) {
      appendAssistantText(delta, to: blockID)
      return
    }

    if let finalText = CodexJSONEventParser.completedAgentMessage(from: object) {
      replaceAssistantText(finalText, to: blockID)
      return
    }

    if let completion = CodexJSONEventParser.turnCompletion(from: object) {
      finishTurn(blockID: blockID, completed: completion.completed, message: completion.message)
      return
    }

    guard var context = appServerContexts[blockID] else {
      return
    }

    if CodexJSONEventParser.isResponse(object, requestID: context.initializeRequestID) {
      sendThreadStart(to: blockID)
      return
    }

    if let threadID = CodexJSONEventParser.threadID(fromThreadStartResponse: object, requestID: context.threadStartRequestID) {
      context.threadID = threadID
      appServerContexts[blockID] = context
      sendTurnStart(to: blockID, threadID: threadID)
      return
    }

    if let turnID = CodexJSONEventParser.turnID(fromTurnStartResponse: object, requestID: context.turnStartRequestID) {
      context.turnID = turnID
      appServerContexts[blockID] = context
    }
  }

  private func appendAssistantText(_ text: String, to blockID: String) {
    var output = output(for: blockID)
    output.text += text
    output.standardOutput += text
    outputs[blockID] = output
  }

  private func replaceAssistantText(_ text: String, to blockID: String) {
    var output = output(for: blockID)
    output.text = text
    output.standardOutput = text
    outputs[blockID] = output
  }

  private func finish(blockID: String, status: Int32) {
    flushJSONLineBuffer(for: blockID)

    var output = output(for: blockID)
    guard output.state == .running else {
      cleanup(blockID: blockID)
      return
    }

    output.state = status == 0 ? .completed : .failed
    if output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      output.text = status == 0 ? "Codex completed without output." : "Codex exited with status \(status)."
      if status == 0 {
        output.standardOutput = output.text
      } else {
        output.standardError = output.text
      }
    }
    outputs[blockID] = output
    cleanup(blockID: blockID)
  }

  private func flushJSONLineBuffer(for blockID: String) {
    guard let line = outputLineBuffers[blockID] else { return }

    outputLineBuffers[blockID] = nil
    handleAppServerLine(line, for: blockID)
  }

  private func finishTurn(blockID: String, completed: Bool, message: String?) {
    var output = output(for: blockID)
    output.state = completed ? .completed : .failed

    if output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      let fallback = completed ? "Codex completed without output." : (message ?? "Codex failed.")
      output.text = fallback
      if completed {
        output.standardOutput = fallback
      } else {
        output.standardError = fallback
      }
    } else if let message, !completed {
      output.standardError += output.standardError.isEmpty ? message : "\n\(message)"
    }

    outputs[blockID] = output
    terminate(blockID: blockID)
  }

  private func fail(blockID: String, message: String) {
    var output = output(for: blockID)
    output.state = .failed
    output.text = message
    output.standardError = message
    outputs[blockID] = output
    terminate(blockID: blockID)
  }

  private func terminate(blockID: String) {
    let process = processes[blockID]
    cleanup(blockID: blockID)
    process?.terminate()
  }

  private func sendInitialize(to blockID: String) {
    guard let context = appServerContexts[blockID] else { return }

    sendRequest(
      id: context.initializeRequestID,
      method: "initialize",
      params: [
        "clientInfo": [
          "name": "Codeck",
          "version": "0.1"
        ],
        "capabilities": [
          "experimentalApi": true
        ]
      ],
      to: blockID
    )
  }

  private func sendThreadStart(to blockID: String) {
    guard let context = appServerContexts[blockID] else { return }

    var params: [String: Any] = [
      "approvalPolicy": "never",
      "ephemeral": true,
      "sandbox": context.block.sandbox ?? context.settings.sandbox,
      "serviceName": "Codeck"
    ]

    if let workingDirectory = context.workingDirectory {
      params["cwd"] = workingDirectory.path
    }

    params["model"] = context.block.model ?? context.settings.model

    sendRequest(id: context.threadStartRequestID, method: "thread/start", params: params, to: blockID)
  }

  private func sendTurnStart(to blockID: String, threadID: String) {
    guard let context = appServerContexts[blockID] else { return }

    var params: [String: Any] = [
      "approvalPolicy": "never",
      "input": [
        [
          "type": "text",
          "text": context.block.prompt
        ]
      ],
      "threadId": threadID
    ]

    if let workingDirectory = context.workingDirectory {
      params["cwd"] = workingDirectory.path
    }

    params["model"] = context.block.model ?? context.settings.model

    params["effort"] = (context.block.reasoning ?? context.settings.reasoning).rawValue

    sendRequest(id: context.turnStartRequestID, method: "turn/start", params: params, to: blockID)
  }

  private func sendRequest(id: String, method: String, params: [String: Any], to blockID: String) {
    let request: [String: Any] = [
      "id": id,
      "method": method,
      "params": params
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: request),
          var payload = String(data: data, encoding: .utf8) else {
      fail(blockID: blockID, message: "Could not encode Codex app-server request.")
      return
    }

    payload += "\n"

    guard let inputPipe = inputPipes[blockID],
          let data = payload.data(using: .utf8) else {
      return
    }

    inputPipe.fileHandleForWriting.write(data)
  }

  private func cleanup(blockID: String) {
    outputPipes[blockID]?.fileHandleForReading.readabilityHandler = nil
    errorPipes[blockID]?.fileHandleForReading.readabilityHandler = nil
    outputPipes[blockID] = nil
    errorPipes[blockID] = nil
    inputPipes[blockID] = nil
    outputLineBuffers[blockID] = nil
    appServerContexts[blockID] = nil
    processes[blockID] = nil
    runningIDs.remove(blockID)
  }
}
