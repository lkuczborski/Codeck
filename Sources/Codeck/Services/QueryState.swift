import CodeckCore
import Foundation

final class QueryState: @unchecked Sendable {
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
            let models = CodexModelListClient.models(from: object)
      else {
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
