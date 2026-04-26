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
      if let data = block.prompt.data(using: .utf8) {
        inputPipe.fileHandleForWriting.write(data)
      }
      try? inputPipe.fileHandleForWriting.close()
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

  private func append(_ text: String, to blockID: String, stream: SessionStream) {
    var output = output(for: blockID)
    output.text += text
    switch stream {
    case .standardOutput:
      output.standardOutput += text
    case .standardError:
      output.standardError += text
    }
    outputs[blockID] = output
  }

  private func finish(blockID: String, status: Int32) {
    var output = output(for: blockID)
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

  private func cleanup(blockID: String) {
    outputPipes[blockID]?.fileHandleForReading.readabilityHandler = nil
    errorPipes[blockID]?.fileHandleForReading.readabilityHandler = nil
    outputPipes[blockID] = nil
    errorPipes[blockID] = nil
    processes[blockID] = nil
    runningIDs.remove(blockID)
  }
}
