import Foundation
import XCTest

final class CodeckMCPServerTests: XCTestCase {
  func testMCPServerSupportsEveryAdvertisedAction() throws {
    let deckPath = "/private/tmp/codeck-mcp-actions-\(UUID().uuidString).mdeck"
    defer { try? FileManager.default.removeItem(atPath: deckPath) }

    let requests: [[String: Any]] = [
      Self.request(1, "initialize", params: [
        "protocolVersion": "2025-11-25",
        "clientInfo": ["name": "codeck-tests", "version": "0"],
        "capabilities": [:]
      ]),
      Self.request(2, "tools/list"),
      Self.request(3, "resources/list"),
      Self.request(4, "resources/templates/list"),
      Self.toolCall(5, "create_deck", [
        "path": deckPath,
        "slides": ["# Intro\n\nFirst slide", "# Agenda\n\n- One\n- Two"],
        "overwrite": true,
        "theme": "studio"
      ]),
      Self.toolCall(6, "read_deck", ["path": deckPath]),
      Self.toolCall(7, "list_slides", ["path": deckPath]),
      Self.toolCall(8, "get_slide", ["path": deckPath, "index": 0]),
      Self.toolCall(9, "set_slide_markdown", [
        "path": deckPath,
        "index": 0,
        "markdown": "# Intro Updated\n\nFirst slide updated"
      ]),
      Self.toolCall(10, "insert_slide", [
        "path": deckPath,
        "position": 1,
        "markdown": "# Inserted\n\nInserted slide"
      ]),
      Self.toolCall(11, "duplicate_slide", ["path": deckPath, "index": 1]),
      Self.toolCall(12, "move_slide", ["path": deckPath, "from_index": 3, "to_index": 1]),
      Self.toolCall(13, "delete_slide", ["path": deckPath, "index": 2]),
      Self.toolCall(14, "set_deck_settings", [
        "path": deckPath,
        "theme": "chalk",
        "model": "gpt-5.4",
        "reasoning": "high",
        "sandbox": "workspace-write"
      ]),
      Self.toolCall(15, "insert_codex_block", [
        "path": deckPath,
        "index": 0,
        "id": "smoke-block",
        "title": "Smoke block",
        "prompt": "Explain the smoke test result.",
        "model": "gpt-5.4",
        "reasoning": "high",
        "sandbox": "read-only"
      ]),
      Self.toolCall(16, "validate_deck", ["path": deckPath]),
      Self.request(17, "resources/read", params: [
        "uri": "codeck://deck?path=\(deckPath)&view=document"
      ]),
      Self.request(18, "resources/read", params: [
        "uri": "codeck://deck?path=\(deckPath)&view=outline"
      ]),
      Self.request(19, "resources/read", params: [
        "uri": "codeck://deck?path=\(deckPath)&view=slide&index=0"
      ])
    ]

    let responses = try runMCPServer(requests: requests, allowedRoots: "/private/tmp")
    XCTAssertEqual(responses.count, requests.count)
    XCTAssertNoThrow(try assertNoProtocolOrToolErrors(in: responses))

    let advertisedTools = try result(for: 2, in: responses)["tools"] as? [[String: Any]]
    XCTAssertEqual(
      Set(advertisedTools?.compactMap { $0["name"] as? String } ?? []),
      Set([
        "create_deck",
        "read_deck",
        "list_slides",
        "get_slide",
        "set_slide_markdown",
        "insert_slide",
        "delete_slide",
        "move_slide",
        "duplicate_slide",
        "set_deck_settings",
        "insert_codex_block",
        "validate_deck"
      ])
    )

    let templateResult = try result(for: 4, in: responses)
    let templates = try XCTUnwrap(templateResult["resourceTemplates"] as? [[String: Any]])
    XCTAssertEqual(templates.first?["uriTemplate"] as? String, "codeck://deck{?path,view,index}")

    let validation = try toolJSONResult(for: 16, in: responses)
    XCTAssertEqual(validation["valid"] as? Bool, true)

    let outlineResource = try resourceJSONResult(for: 18, in: responses)
    let deck = try XCTUnwrap(outlineResource["deck"] as? [String: Any])
    XCTAssertEqual(deck["theme"] as? String, "chalk")

    let codex = try XCTUnwrap(deck["codex"] as? [String: Any])
    XCTAssertEqual(codex["model"] as? String, "gpt-5.4")
    XCTAssertEqual(codex["reasoning"] as? String, "high")
    XCTAssertEqual(codex["sandbox"] as? String, "workspace-write")

    let slides = try XCTUnwrap(deck["slides"] as? [[String: Any]])
    XCTAssertEqual(slides.compactMap { $0["title"] as? String }, ["Intro Updated", "Agenda", "Inserted"])
    XCTAssertEqual(slides.first?["codexBlockCount"] as? Int, 1)

    let document = try resourceText(for: 17, in: responses)
    XCTAssertTrue(document.contains("theme: chalk"))
    XCTAssertTrue(document.contains("```codex id=smoke-block"))

    let slide = try resourceJSONResult(for: 19, in: responses)
    let slideDescription = try XCTUnwrap(slide["slide"] as? [String: Any])
    XCTAssertEqual(slideDescription["title"] as? String, "Intro Updated")
    XCTAssertEqual(slideDescription["codexBlockCount"] as? Int, 1)
  }

  private func runMCPServer(requests: [[String: Any]], allowedRoots: String) throws -> [[String: Any]] {
    let process = Process()
    process.executableURL = serverExecutableURL()
    process.currentDirectoryURL = packageRootURL()

    var environment = ProcessInfo.processInfo.environment
    environment["CODECK_MCP_ALLOWED_ROOTS"] = allowedRoots
    process.environment = environment

    let input = Pipe()
    let output = Pipe()
    let error = Pipe()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = error

    try process.run()

    for request in requests {
      let data = try JSONSerialization.data(withJSONObject: request)
      input.fileHandleForWriting.write(data)
      input.fileHandleForWriting.write(Data("\n".utf8))
    }
    input.fileHandleForWriting.closeFile()

    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = error.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let stderr = String(decoding: errorData, as: UTF8.self)
    XCTAssertTrue(stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, stderr)
    XCTAssertEqual(process.terminationStatus, 0)

    let outputText = String(decoding: outputData, as: UTF8.self)
    return try outputText
      .split(separator: "\n")
      .map { line in
        let data = Data(line.utf8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          throw TestError.invalidJSONLine(String(line))
        }
        return object
      }
  }

  private func assertNoProtocolOrToolErrors(in responses: [[String: Any]]) throws {
    for response in responses {
      let id = response["id"] ?? "unknown"
      if let error = response["error"] as? [String: Any] {
        XCTFail("MCP response \(id) failed: \(error)")
      }
      guard let result = response["result"] as? [String: Any] else {
        continue
      }
      if result["isError"] as? Bool == true {
        let content = result["content"] as? [[String: Any]]
        let message = content?.first?["text"] as? String ?? "Unknown tool error"
        XCTFail("MCP tool response \(id) failed: \(message)")
      }
    }
  }

  private func result(for id: Int, in responses: [[String: Any]]) throws -> [String: Any] {
    let response = try XCTUnwrap(responses.first { ($0["id"] as? Int) == id })
    return try XCTUnwrap(response["result"] as? [String: Any])
  }

  private func toolJSONResult(for id: Int, in responses: [[String: Any]]) throws -> [String: Any] {
    let text = try toolText(for: id, in: responses)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
  }

  private func toolText(for id: Int, in responses: [[String: Any]]) throws -> String {
    let result = try result(for: id, in: responses)
    let content = try XCTUnwrap(result["content"] as? [[String: Any]])
    return try XCTUnwrap(content.first?["text"] as? String)
  }

  private func resourceJSONResult(for id: Int, in responses: [[String: Any]]) throws -> [String: Any] {
    let text = try resourceText(for: id, in: responses)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
  }

  private func resourceText(for id: Int, in responses: [[String: Any]]) throws -> String {
    let result = try result(for: id, in: responses)
    let contents = try XCTUnwrap(result["contents"] as? [[String: Any]])
    return try XCTUnwrap(contents.first?["text"] as? String)
  }

  private func serverExecutableURL() -> URL {
    packageRootURL()
      .appendingPathComponent(".build")
      .appendingPathComponent("debug")
      .appendingPathComponent("codeck-mcp")
  }

  private func packageRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private static func request(_ id: Int, _ method: String, params: [String: Any] = [:]) -> [String: Any] {
    [
      "jsonrpc": "2.0",
      "id": id,
      "method": method,
      "params": params
    ]
  }

  private static func toolCall(_ id: Int, _ name: String, _ arguments: [String: Any]) -> [String: Any] {
    Self.request(id, "tools/call", params: [
      "name": name,
      "arguments": arguments
    ])
  }

  private enum TestError: Error {
    case invalidJSONLine(String)
  }
}
