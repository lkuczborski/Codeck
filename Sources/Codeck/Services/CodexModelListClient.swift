import Foundation

enum CodexModelListClient {
  private static let initializeRequestID = "codeck-initialize"
  private static let modelListRequestID = "codeck-model-list"

  static func fetchModels(timeout: TimeInterval = 5) async throws -> [CodexModelOption] {
    try await Task.detached(priority: .userInitiated) {
      try queryModels(timeout: timeout)
    }.value
  }

  static func models(from object: [String: Any], requestID: String = modelListRequestID) -> [CodexModelOption]? {
    guard requestIDMatches(object["id"], requestID: requestID) else {
      return nil
    }

    if let result = object["result"] as? [String: Any],
       let models = models(fromPayload: result["models"]) {
      return models
    }

    if let result = object["result"] as? [String: Any],
       let models = models(fromPayload: result["data"]) {
      return models
    }

    return models(fromPayload: object["models"]) ?? models(fromPayload: object["data"])
  }

  private static func queryModels(timeout: TimeInterval) throws -> [CodexModelOption] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["codex", "app-server", "--listen", "stdio://"]

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    let inputPipe = Pipe()
    let state = QueryState()

    process.standardOutput = outputPipe
    process.standardError = errorPipe
    process.standardInput = inputPipe

    outputPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      state.appendOutput(String(decoding: data, as: UTF8.self))
    }

    errorPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      state.appendError(String(decoding: data, as: UTF8.self))
    }

    process.terminationHandler = { process in
      guard process.terminationStatus != 0 else { return }
      state.complete(.failure(ClientError.processExited(process.terminationStatus, state.errorText)))
    }

    do {
      try process.run()
      try sendInitialize(to: inputPipe)
      try sendModelListRequest(to: inputPipe)
    } catch {
      outputPipe.fileHandleForReading.readabilityHandler = nil
      errorPipe.fileHandleForReading.readabilityHandler = nil
      process.terminate()
      throw error
    }

    let waitResult = state.wait(timeout: timeout)
    outputPipe.fileHandleForReading.readabilityHandler = nil
    errorPipe.fileHandleForReading.readabilityHandler = nil

    if process.isRunning {
      process.terminate()
    }

    switch waitResult {
    case .success(let models):
      return models
    case .failure(let error):
      throw error
    }
  }

  private static func sendInitialize(to inputPipe: Pipe) throws {
    try sendRequest(
      id: initializeRequestID,
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
      to: inputPipe
    )
  }

  private static func sendModelListRequest(to inputPipe: Pipe) throws {
    try sendRequest(
      id: modelListRequestID,
      method: "model/list",
      params: ["includeHidden": false],
      to: inputPipe
    )
  }

  private static func sendRequest(id: String, method: String, params: [String: Any], to inputPipe: Pipe) throws {
    let request: [String: Any] = [
      "id": id,
      "method": method,
      "params": params
    ]

    let data = try JSONSerialization.data(withJSONObject: request)
    guard let payload = String(data: data, encoding: .utf8),
          let payloadData = "\(payload)\n".data(using: .utf8) else {
      throw ClientError.encodingFailed
    }

    inputPipe.fileHandleForWriting.write(payloadData)
  }

  private static func models(fromPayload payload: Any?) -> [CodexModelOption]? {
    guard let payload else { return nil }

    let dictionaries: [[String: Any]]
    if let array = payload as? [[String: Any]] {
      dictionaries = array
    } else if let array = payload as? [Any] {
      dictionaries = array.compactMap { $0 as? [String: Any] }
    } else {
      return nil
    }

    let models = dictionaries.compactMap(modelOption(from:))
    return models.isEmpty ? nil : models
  }

  private static func modelOption(from dictionary: [String: Any]) -> CodexModelOption? {
    guard let id = dictionary["id"] as? String ?? dictionary["model"] as? String else {
      return nil
    }

    let supportedReasoningEfforts = stringArray(
      from: dictionary["supportedReasoningEfforts"] ?? dictionary["supported_reasoning_efforts"]
    )
    .map(CodexReasoningEffort.init(rawValue:))

    let defaultReasoningValue = dictionary["defaultReasoningEffort"] as? String
      ?? dictionary["default_reasoning_effort"] as? String

    return CodexModelOption(
      id: id,
      displayName: dictionary["displayName"] as? String ?? dictionary["display_name"] as? String ?? id,
      description: dictionary["description"] as? String ?? "",
      supportedReasoningEfforts: supportedReasoningEfforts.isEmpty ? CodexReasoningEffort.allCases : supportedReasoningEfforts,
      defaultReasoningEffort: defaultReasoningValue.map(CodexReasoningEffort.init(rawValue:)) ?? .medium,
      isDefault: dictionary["isDefault"] as? Bool ?? dictionary["is_default"] as? Bool ?? false
    )
  }

  private static func stringArray(from value: Any?) -> [String] {
    if let strings = value as? [String] {
      return strings
    }

    if let values = value as? [Any] {
      return values.compactMap { value in
        if let string = value as? String {
          return string
        }

        if let dictionary = value as? [String: Any] {
          return dictionary["reasoningEffort"] as? String
            ?? dictionary["reasoning_effort"] as? String
            ?? dictionary["id"] as? String
        }

        return nil
      }
    }

    return []
  }

  private static func requestIDMatches(_ value: Any?, requestID: String) -> Bool {
    if let string = value as? String {
      return string == requestID
    }

    if let number = value as? NSNumber {
      return number.stringValue == requestID
    }

    return false
  }
}

private final class QueryState: @unchecked Sendable {
  private let lock = NSLock()
  private let semaphore = DispatchSemaphore(value: 0)
  private var outputBuffer = ""
  private var result: Result<[CodexModelOption], Error>?
  private var stderr = ""

  var errorText: String {
    lock.lock()
    defer { lock.unlock() }
    return stderr
  }

  func appendOutput(_ text: String) {
    let lines = bufferedLines(afterAppending: text)

    for line in lines {
      guard let object = CodexJSONEventParser.object(from: line),
            let models = CodexModelListClient.models(from: object) else {
        continue
      }

      complete(.success(models))
    }
  }

  func appendError(_ text: String) {
    lock.lock()
    stderr += text
    lock.unlock()
  }

  func complete(_ result: Result<[CodexModelOption], Error>) {
    lock.lock()
    guard self.result == nil else {
      lock.unlock()
      return
    }

    self.result = result
    lock.unlock()
    semaphore.signal()
  }

  func wait(timeout: TimeInterval) -> Result<[CodexModelOption], Error> {
    let deadline = DispatchTime.now() + timeout
    if semaphore.wait(timeout: deadline) == .timedOut {
      return .failure(CodexModelListClient.ClientError.timedOut)
    }

    lock.lock()
    defer { lock.unlock() }
    return result ?? .failure(CodexModelListClient.ClientError.missingResponse)
  }

  private func bufferedLines(afterAppending text: String) -> [String] {
    lock.lock()
    outputBuffer += text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    let lines = outputBuffer.components(separatedBy: "\n")
    outputBuffer = lines.last ?? ""
    lock.unlock()

    return Array(lines.dropLast())
  }
}

extension CodexModelListClient {
  enum ClientError: LocalizedError {
    case encodingFailed
    case missingResponse
    case processExited(Int32, String)
    case timedOut

    var errorDescription: String? {
      switch self {
      case .encodingFailed:
        "Could not encode the Codex model list request."
      case .missingResponse:
        "Codex did not return a model list."
      case .processExited(let status, let errorText):
        if errorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          "Codex model list exited with status \(status)."
        } else {
          "Codex model list exited with status \(status): \(errorText)"
        }
      case .timedOut:
        "Codex model list request timed out."
      }
    }
  }
}
