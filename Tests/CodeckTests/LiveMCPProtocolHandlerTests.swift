import CodeckCore
import XCTest
@testable import Codeck

@MainActor
final class LiveMCPProtocolHandlerTests: XCTestCase {
  func testLiveMCPHandlerSupportsEditingAndWindowActions() throws {
    let registry = LiveMCPDocumentRegistry.shared
    let documentID = UUID()
    var deck = PresentationDeck(
      theme: .studio,
      slides: [
        Slide(markdown: "# Intro\n\nFirst slide"),
        Slide(markdown: "# Agenda\n\n- One\n- Two")
      ]
    )
    var selectedIndex: Int? = 0
    var presentationStarted = false
    var presentationStopped = false

    registry.register(
      LiveMCPDocumentSession(
        id: documentID,
        fileURL: { URL(fileURLWithPath: "/tmp/LiveBridge.mdeck") },
        deck: { deck },
        setDeck: { deck = $0 },
        selectedSlideIndex: { selectedIndex },
        selectSlide: { selectedIndex = $0 },
        present: { presentationStarted = true },
        dismissPresentation: { presentationStopped = true }
      )
    )
    defer { registry.unregister(documentID) }

    let handler = LiveMCPProtocolHandler(registry: registry)
    let responses = try [
      Self.request(1, "initialize", params: ["protocolVersion": LiveMCPSettings.protocolVersion, "capabilities": [:], "clientInfo": ["name": "tests"]]),
      Self.request(2, "tools/list"),
      Self.request(3, "resources/list"),
      Self.request(4, "resources/templates/list"),
      Self.toolCall(5, "list_open_decks", [:]),
      Self.toolCall(6, "read_deck", ["document_id": documentID.uuidString]),
      Self.toolCall(7, "list_slides", ["document_id": documentID.uuidString]),
      Self.toolCall(8, "get_slide", ["document_id": documentID.uuidString, "index": 0]),
      Self.toolCall(9, "set_slide_markdown", [
        "document_id": documentID.uuidString,
        "index": 0,
        "markdown": "# Intro Updated\n\nFirst slide updated"
      ]),
      Self.toolCall(10, "insert_slide", [
        "document_id": documentID.uuidString,
        "position": 1,
        "markdown": "# Inserted\n\nInserted slide"
      ]),
      Self.toolCall(11, "duplicate_slide", ["document_id": documentID.uuidString, "index": 1]),
      Self.toolCall(12, "move_slide", ["document_id": documentID.uuidString, "from_index": 3, "to_index": 1]),
      Self.toolCall(13, "delete_slide", ["document_id": documentID.uuidString, "index": 2]),
      Self.toolCall(14, "set_deck_settings", [
        "document_id": documentID.uuidString,
        "theme": "chalk",
        "model": "gpt-5.4",
        "reasoning": "high",
        "sandbox": "workspace-write"
      ]),
      Self.toolCall(15, "insert_codex_block", [
        "document_id": documentID.uuidString,
        "index": 0,
        "id": "live-block",
        "title": "Live block",
        "prompt": "Explain this bridge.",
        "model": "gpt-5.4",
        "reasoning": "high",
        "sandbox": "read-only"
      ]),
      Self.toolCall(16, "select_slide", ["document_id": documentID.uuidString, "index": 1]),
      Self.toolCall(17, "get_selection", ["document_id": documentID.uuidString]),
      Self.toolCall(18, "start_presentation", ["document_id": documentID.uuidString]),
      Self.toolCall(19, "stop_presentation", ["document_id": documentID.uuidString]),
      Self.toolCall(20, "validate_deck", ["document_id": documentID.uuidString]),
      Self.request(21, "resources/read", params: [
        "uri": "codeck-live://deck/\(documentID.uuidString)?view=document"
      ]),
      Self.request(22, "resources/read", params: [
        "uri": "codeck-live://deck/\(documentID.uuidString)?view=outline"
      ]),
      Self.request(23, "resources/read", params: [
        "uri": "codeck-live://deck/\(documentID.uuidString)?view=slide&index=0"
      ])
    ].map { try handle($0, with: handler) }

    try assertNoProtocolOrToolErrors(in: responses)
    XCTAssertTrue(presentationStarted)
    XCTAssertTrue(presentationStopped)
    XCTAssertEqual(selectedIndex, 1)

    let tools = try XCTUnwrap(result(for: 2, in: responses)["tools"] as? [[String: Any]])
    XCTAssertTrue(tools.contains { $0["name"] as? String == "select_slide" })
    XCTAssertTrue(tools.contains { $0["name"] as? String == "start_presentation" })

    let openDecks = try toolJSONResult(for: 5, in: responses)
    let documents = try XCTUnwrap(openDecks["documents"] as? [[String: Any]])
    XCTAssertEqual(documents.first?["documentID"] as? String, documentID.uuidString)

    let validation = try toolJSONResult(for: 20, in: responses)
    XCTAssertEqual(validation["valid"] as? Bool, true)

    let outlineResource = try resourceJSONResult(for: 22, in: responses)
    let liveDeck = try XCTUnwrap(outlineResource["deck"] as? [String: Any])
    XCTAssertEqual(liveDeck["theme"] as? String, "chalk")
    XCTAssertEqual((liveDeck["slides"] as? [[String: Any]])?.compactMap { $0["title"] as? String }, ["Intro Updated", "Agenda", "Inserted"])

    let documentMarkdown = try resourceText(for: 21, in: responses)
    XCTAssertTrue(documentMarkdown.contains("```codex id=live-block"))
  }

  func testLiveMCPRequiresDocumentIDWhenMultipleDecksAreOpen() throws {
    let registry = LiveMCPDocumentRegistry.shared
    let firstDocumentID = UUID()
    let secondDocumentID = UUID()
    var firstDeck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# First")])
    var secondDeck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# Second")])

    registry.register(
      LiveMCPDocumentSession(
        id: firstDocumentID,
        fileURL: { nil },
        deck: { firstDeck },
        setDeck: { firstDeck = $0 },
        selectedSlideIndex: { 0 },
        selectSlide: { _ in },
        present: {},
        dismissPresentation: {}
      )
    )
    registry.register(
      LiveMCPDocumentSession(
        id: secondDocumentID,
        fileURL: { nil },
        deck: { secondDeck },
        setDeck: { secondDeck = $0 },
        selectedSlideIndex: { 0 },
        selectSlide: { _ in },
        present: {},
        dismissPresentation: {}
      )
    )
    defer {
      registry.unregister(firstDocumentID)
      registry.unregister(secondDocumentID)
    }

    let handler = LiveMCPProtocolHandler(registry: registry)
    let response = try handle(Self.toolCall(1, "list_slides", [:]), with: handler)

    let result = try XCTUnwrap(response["result"] as? [String: Any])
    XCTAssertEqual(result["isError"] as? Bool, true)
    XCTAssertTrue(try toolText(for: 1, in: [response]).contains("Multiple Codeck documents are open"))
  }

  func testLiveMCPSelectsSlidesAfterInstallingMutatedDeck() throws {
    let registry = LiveMCPDocumentRegistry.shared
    let documentID = UUID()
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# Intro")])
    var selectedIndex: Int? = 0

    registry.register(
      LiveMCPDocumentSession(
        id: documentID,
        fileURL: { nil },
        deck: { deck },
        setDeck: { deck = $0 },
        selectedSlideIndex: { selectedIndex },
        selectSlide: { index in
          guard deck.slides.indices.contains(index) else { return }
          selectedIndex = index
        },
        present: {},
        dismissPresentation: {}
      )
    )
    defer { registry.unregister(documentID) }

    let handler = LiveMCPProtocolHandler(registry: registry)
    let insertResponse = try handle(
      Self.toolCall(1, "insert_slide", [
        "document_id": documentID.uuidString,
        "position": 1,
        "markdown": "# Appended"
      ]),
      with: handler
    )
    try assertNoProtocolOrToolErrors(in: [insertResponse])
    XCTAssertEqual(deck.slides.map(\.title), ["Intro", "Appended"])
    XCTAssertEqual(selectedIndex, 1)

    deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# Single")])
    selectedIndex = 0

    let splitResponse = try handle(
      Self.toolCall(2, "set_slide_markdown", [
        "document_id": documentID.uuidString,
        "index": 0,
        "markdown": "# First\n\n---\n\n# Split"
      ]),
      with: handler
    )
    try assertNoProtocolOrToolErrors(in: [splitResponse])
    XCTAssertEqual(deck.slides.map(\.title), ["First", "Split"])
    XCTAssertEqual(selectedIndex, 1)
  }

  func testLiveMCPHTTPServerRespondsOverLocalhost() async throws {
    let port = UInt16.random(in: 51000...55000)
    let server = LiveMCPHTTPServer(port: port, handler: LiveMCPProtocolHandler())
    try server.start()
    defer { server.stop() }

    var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/mcp")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("tools/list", forHTTPHeaderField: "Mcp-Method")
    request.httpBody = try JSONSerialization.data(withJSONObject: Self.request(1, "tools/list"))

    let (data, response) = try await URLSession.shared.data(for: request)
    XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)

    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let result = try XCTUnwrap(object["result"] as? [String: Any])
    let tools = try XCTUnwrap(result["tools"] as? [[String: Any]])
    XCTAssertTrue(tools.contains { $0["name"] as? String == "list_open_decks" })
  }

  private func handle(_ request: [String: Any], with handler: LiveMCPProtocolHandler) throws -> [String: Any] {
    let data = try JSONSerialization.data(withJSONObject: request)
    return try XCTUnwrap(handler.handleJSONData(data) as? [String: Any])
  }

  private func assertNoProtocolOrToolErrors(in responses: [[String: Any]]) throws {
    for response in responses {
      if let error = response["error"] as? [String: Any] {
        XCTFail("MCP response failed: \(error)")
      }
      guard let result = response["result"] as? [String: Any] else {
        continue
      }
      if result["isError"] as? Bool == true {
        let content = result["content"] as? [[String: Any]]
        let message = content?.first?["text"] as? String ?? "Unknown tool error"
        XCTFail("MCP tool response failed: \(message)")
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
}
