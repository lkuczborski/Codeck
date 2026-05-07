import CodeckCore
import Foundation

@MainActor
final class LiveMCPProtocolHandler {
  private let registry: LiveMCPDocumentRegistry
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return encoder
  }()

  init(registry: LiveMCPDocumentRegistry = .shared) {
    self.registry = registry
  }

  func handleJSONData(_ data: Data) -> Any? {
    do {
      let message = try JSONSerialization.jsonObject(with: data)
      if let batch = message as? [[String: Any]] {
        let responses = batch.compactMap(handleMessage)
        return responses.isEmpty ? nil : responses
      }
      guard let object = message as? [String: Any] else {
        return errorResponse(id: nil, code: -32600, message: "Invalid JSON-RPC message.")
      }
      return handleMessage(object)
    } catch {
      return errorResponse(id: nil, code: -32700, message: "Parse error: \(error.localizedDescription)")
    }
  }

  private func handleMessage(_ message: [String: Any]) -> [String: Any]? {
    let id = message["id"]
    guard let method = message["method"] as? String else {
      return errorResponse(id: id, code: -32600, message: "Missing method.")
    }

    do {
      switch method {
      case "initialize":
        return response(id: id, result: initializeResult(params: message["params"] as? [String: Any]))
      case "notifications/initialized":
        return nil
      case "ping":
        return response(id: id, result: [:])
      case "tools/list":
        return response(id: id, result: ["tools": tools])
      case "tools/call":
        return response(id: id, result: callToolResult(params: try dictionaryParams(message["params"])))
      case "resources/list":
        return response(id: id, result: ["resources": resourceList])
      case "resources/templates/list":
        return response(id: id, result: ["resourceTemplates": resourceTemplates])
      case "resources/read":
        return response(id: id, result: try readResourceResult(params: try dictionaryParams(message["params"])))
      default:
        return errorResponse(id: id, code: -32601, message: "Unknown method: \(method)")
      }
    } catch let error as LiveMCPError {
      return errorResponse(id: id, code: error.jsonRPCCode, message: error.localizedDescription)
    } catch {
      return errorResponse(id: id, code: -32603, message: error.localizedDescription)
    }
  }

  private func initializeResult(params: [String: Any]?) -> [String: Any] {
    let protocolVersion = params?["protocolVersion"] as? String ?? LiveMCPSettings.protocolVersion
    return [
      "protocolVersion": protocolVersion,
      "capabilities": [
        "tools": ["listChanged": true],
        "resources": ["listChanged": true]
      ],
      "serverInfo": [
        "name": "codeck",
        "version": "0.1.0"
      ],
      "instructions": """
      Edit open Codeck document windows. Use list_open_decks to find document_id values; if only one deck is open, document_id can be omitted.
      """
    ]
  }

  private func callToolResult(params: [String: Any]) -> [String: Any] {
    guard let name = params["name"] as? String else {
      return toolError("Missing tool name.")
    }

    let arguments = params["arguments"] as? [String: Any] ?? [:]
    do {
      let result = try callTool(name: name, arguments: arguments)
      return ["content": [["type": "text", "text": result]], "isError": false]
    } catch {
      return toolError(error.localizedDescription)
    }
  }

  private func callTool(name: String, arguments: [String: Any]) throws -> String {
    switch name {
    case "list_open_decks":
      return try jsonText(OpenDecksResponse(documents: registry.listDocuments().map(OpenDocumentDescription.init)))
    case "read_deck":
      let document = try document(from: arguments)
      let deck = document.deck()
      return try jsonText(LiveDeckResponse(document: document, deck: deck, markdown: deck.deckDocument))
    case "list_slides":
      let document = try document(from: arguments)
      return try jsonText(LiveDeckResponse(document: document, deck: document.deck(), markdown: nil))
    case "get_slide":
      let document = try document(from: arguments)
      let deck = document.deck()
      let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
      return try jsonText(LiveSlideResponse(document: document, index: index, slide: deck.slides[index]))
    case "set_slide_markdown":
      return try mutateDeck(arguments, message: "Slide updated.") { deck, _ in
        let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
        let markdown = try requiredString(arguments, "markdown")
        let slideID = deck.slides[index].id
        let result = deck.replaceSlideMarkdown(for: slideID, with: markdown)
        return result.flatMap { result in
          deck.slides.firstIndex(where: { $0.id == result.selectedSlideID })
        }
      }
    case "insert_slide":
      return try mutateDeck(arguments, message: "Slide inserted.") { deck, _ in
        let markdown = optionalString(arguments, "markdown") ?? PresentationDeck.defaultSlideMarkdown
        let position = try optionalInt(arguments, "position").map { try boundedInsertionIndex($0, count: deck.slides.count) } ?? deck.slides.count
        deck.slides.insert(Slide(markdown: markdown), at: position)
        return position
      }
    case "delete_slide":
      return try mutateDeck(arguments, message: "Slide deleted.") { deck, _ in
        guard deck.slides.count > 1 else {
          throw LiveMCPError.operationFailed("A Codeck deck must keep at least one slide.")
        }
        let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
        deck.slides.remove(at: index)
        return min(index, deck.slides.count - 1)
      }
    case "move_slide":
      return try mutateDeck(arguments, message: "Slide moved.") { deck, _ in
        let fromIndex = try requiredIndex(arguments, "from_index", in: deck.slides.indices)
        let toIndex = try boundedInsertionIndex(try requiredInt(arguments, "to_index"), count: deck.slides.count)
        let slide = deck.slides.remove(at: fromIndex)
        let adjustedDestination = min(toIndex, deck.slides.count)
        deck.slides.insert(slide, at: adjustedDestination)
        return adjustedDestination
      }
    case "duplicate_slide":
      return try mutateDeck(arguments, message: "Slide duplicated.") { deck, _ in
        let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
        deck.slides.insert(Slide(markdown: deck.slides[index].markdown), at: index + 1)
        return index + 1
      }
    case "set_deck_settings":
      return try mutateDeck(arguments, message: "Deck settings updated.") { deck, _ in
        if let rawTheme = optionalString(arguments, "theme") {
          guard let theme = PresentationTheme(rawValue: rawTheme) else {
            throw LiveMCPError.invalidParams("Unsupported theme '\(rawTheme)'.")
          }
          deck.settings.theme = theme
        }
        if let model = optionalString(arguments, "model") {
          deck.settings.codex.model = model
        }
        if let reasoning = optionalString(arguments, "reasoning") {
          deck.settings.codex.reasoning = CodexReasoningEffort(rawValue: reasoning)
        }
        if let sandbox = optionalString(arguments, "sandbox") {
          deck.settings.codex.sandbox = sandbox
        }
        return nil
      }
    case "insert_codex_block":
      return try mutateDeck(arguments, message: "Codex block inserted.") { deck, _ in
        let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
        let prompt = optionalString(arguments, "prompt") ?? "Explain this concept with one concrete example."
        let blockID = optionalString(arguments, "id") ?? "demo-\(deck.slides[index].codexBlocks.count + 1)"
        try validateCodexBlockID(blockID)
        let title = optionalString(arguments, "title") ?? "Describe the goal for this prompt"
        var metadata = ["title: \(metadataValue(title))"]
        if let model = optionalString(arguments, "model") {
          metadata.append("model: \(metadataValue(model))")
        }
        if let reasoning = optionalString(arguments, "reasoning") {
          metadata.append("reasoning: \(metadataValue(reasoning))")
        }
        if let sandbox = optionalString(arguments, "sandbox") {
          metadata.append("sandbox: \(metadataValue(sandbox))")
        }
        let body = (metadata + ["", prompt]).joined(separator: "\n")
        let fence = fenceMarker(for: body)
        deck.slides[index].markdown += "\n\n\(fence)codex id=\(blockID)\n\(body)\n\(fence)"
        return index
      }
    case "select_slide":
      let document = try document(from: arguments)
      let deck = document.deck()
      let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
      document.selectSlide(index)
      return try jsonText(LiveMutationResponse(document: document, message: "Slide selected.", deck: deck))
    case "get_selection":
      let document = try document(from: arguments)
      return try jsonText(SelectionResponse(document: document))
    case "start_presentation":
      let document = try document(from: arguments)
      document.present()
      return try jsonText(LiveMutationResponse(document: document, message: "Presentation started.", deck: document.deck()))
    case "stop_presentation":
      let document = try document(from: arguments)
      document.dismissPresentation()
      return try jsonText(LiveMutationResponse(document: document, message: "Presentation stopped.", deck: document.deck()))
    case "validate_deck":
      let document = try document(from: arguments)
      return try jsonText(LiveValidationResponse(document: document, valid: true, warnings: [], deck: document.deck()))
    default:
      throw LiveMCPError.invalidParams("Unknown tool: \(name)")
    }
  }

  private func mutateDeck(
    _ arguments: [String: Any],
    message: String,
    mutation: (inout PresentationDeck, LiveMCPDocumentSession) throws -> Int?
  ) throws -> String {
    let document = try document(from: arguments)
    var deck = document.deck()
    let selectedIndex = try mutation(&deck, document)
    document.setDeck(deck)
    if let selectedIndex, deck.slides.indices.contains(selectedIndex) {
      document.selectSlide(selectedIndex)
    }
    return try jsonText(LiveMutationResponse(document: document, message: message, deck: deck))
  }

  private func readResourceResult(params: [String: Any]) throws -> [String: Any] {
    guard let uri = params["uri"] as? String else {
      throw LiveMCPError.invalidParams("Missing resource uri.")
    }
    let resource = try resourceContent(for: uri)
    return [
      "contents": [
        [
          "uri": uri,
          "mimeType": resource.mimeType,
          "text": resource.text
        ]
      ]
    ]
  }

  private func resourceContent(for uri: String) throws -> (mimeType: String, text: String) {
    guard let components = URLComponents(string: uri),
          components.scheme == "codeck",
          components.host == "deck" else {
      throw LiveMCPError.invalidParams("Unsupported resource URI. Use codeck://deck/<document_id>?view=document|outline|slide.")
    }

    let documentID = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let document = try registry.resolveDocument(id: documentID.isEmpty ? nil : documentID)
    let query = (components.queryItems ?? []).reduce(into: [String: String]()) { result, item in
      if let value = item.value {
        result[item.name] = value
      }
    }
    let deck = document.deck()

    switch query["view"] ?? "outline" {
    case "document":
      return ("text/markdown", deck.deckDocument)
    case "outline":
      return ("application/json", try jsonText(LiveDeckResponse(document: document, deck: deck, markdown: nil)))
    case "slide":
      guard let rawIndex = query["index"], let index = Int(rawIndex), deck.slides.indices.contains(index) else {
        throw LiveMCPError.invalidParams("Slide resources require a valid index query item.")
      }
      return ("application/json", try jsonText(LiveSlideResponse(document: document, index: index, slide: deck.slides[index])))
    default:
      throw LiveMCPError.invalidParams("Unsupported resource view.")
    }
  }

  private func document(from arguments: [String: Any]) throws -> LiveMCPDocumentSession {
    try registry.resolveDocument(id: optionalString(arguments, "document_id"))
  }

  private var resourceList: [[String: Any]] {
    registry.listDocuments().map { document in
      [
        "uri": "codeck://deck/\(document.id.uuidString)?view=outline",
        "name": document.displayName,
        "mimeType": "application/json",
        "description": "Open Codeck deck outline"
      ]
    }
  }

  private var resourceTemplates: [[String: Any]] {
    [
      [
        "name": "Open Codeck deck",
        "description": "Read an open deck document, outline, or slide. Use view=document, view=outline, or view=slide with index.",
        "uriTemplate": "codeck://deck/{document_id}{?view,index}"
      ]
    ]
  }

  private var tools: [[String: Any]] {
    [
      tool("list_open_decks", "List open Codeck document windows and their document_id values."),
      tool("read_deck", "Read an open Codeck deck as Markdown plus structured outline.", properties: documentProperties),
      tool("list_slides", "Return slide titles, summaries, and Codex block counts.", properties: documentProperties),
      tool(
        "get_slide",
        "Read one slide by zero-based index.",
        properties: documentProperties.merging(["index": integerSchema("Zero-based slide index.")]) { _, new in new },
        required: ["index"]
      ),
      tool(
        "set_slide_markdown",
        "Replace one slide's Markdown. If the Markdown contains slide separators, Codeck splits it into slides.",
        properties: documentProperties.merging([
          "index": integerSchema("Zero-based slide index."),
          "markdown": stringSchema("Replacement slide Markdown.")
        ]) { _, new in new },
        required: ["index", "markdown"]
      ),
      tool(
        "insert_slide",
        "Insert a slide at position, or append when omitted.",
        properties: documentProperties.merging([
          "position": integerSchema("Zero-based insertion position from 0 through slide count."),
          "markdown": stringSchema("New slide Markdown.")
        ]) { _, new in new }
      ),
      tool("delete_slide", "Delete a slide by zero-based index.", properties: indexedDocumentProperties, required: ["index"]),
      tool(
        "move_slide",
        "Move a slide. to_index is the insertion index after removing the slide.",
        properties: documentProperties.merging([
          "from_index": integerSchema("Current zero-based slide index."),
          "to_index": integerSchema("Destination insertion index.")
        ]) { _, new in new },
        required: ["from_index", "to_index"]
      ),
      tool("duplicate_slide", "Duplicate a slide immediately after itself.", properties: indexedDocumentProperties, required: ["index"]),
      tool(
        "set_deck_settings",
        "Update deck theme or deck-level Codex defaults.",
        properties: documentProperties.merging([
          "theme": enumSchema(PresentationTheme.allCases.map(\.rawValue)),
          "model": stringSchema("Deck-level Codex model."),
          "reasoning": stringSchema("Deck-level Codex reasoning effort."),
          "sandbox": stringSchema("Deck-level Codex sandbox.")
        ]) { _, new in new }
      ),
      tool(
        "insert_codex_block",
        "Append a runnable Codex block to a slide.",
        properties: indexedDocumentProperties.merging([
          "id": stringSchema("Optional block id. Must not contain whitespace."),
          "title": stringSchema("Human-readable Codex card title."),
          "prompt": stringSchema("Prompt body for the Codex block."),
          "model": stringSchema("Optional block-level model override."),
          "reasoning": stringSchema("Optional block-level reasoning override."),
          "sandbox": stringSchema("Optional block-level sandbox override.")
        ]) { _, new in new },
        required: ["index"]
      ),
      tool("select_slide", "Select a slide in the Codeck window.", properties: indexedDocumentProperties, required: ["index"]),
      tool("get_selection", "Read the selected slide index.", properties: documentProperties),
      tool("start_presentation", "Start presentation mode from the selected slide.", properties: documentProperties),
      tool("stop_presentation", "Stop presentation mode.", properties: documentProperties),
      tool("validate_deck", "Parse the live deck and return validation status plus outline.", properties: documentProperties)
    ]
  }

  private var documentProperties: [String: Any] {
    ["document_id": stringSchema("Open Codeck document UUID. Can be omitted when only one deck is open.")]
  }

  private var indexedDocumentProperties: [String: Any] {
    documentProperties.merging(["index": integerSchema("Zero-based slide index.")]) { _, new in new }
  }

  private func dictionaryParams(_ value: Any?) throws -> [String: Any] {
    guard let params = value as? [String: Any] else {
      throw LiveMCPError.invalidParams("Expected object params.")
    }
    return params
  }

  private func response(id: Any?, result: [String: Any]) -> [String: Any] {
    ["jsonrpc": "2.0", "id": id ?? NSNull(), "result": result]
  }

  private func errorResponse(id: Any?, code: Int, message: String) -> [String: Any] {
    [
      "jsonrpc": "2.0",
      "id": id ?? NSNull(),
      "error": [
        "code": code,
        "message": message
      ]
    ]
  }

  private func toolError(_ message: String) -> [String: Any] {
    ["content": [["type": "text", "text": message]], "isError": true]
  }

  private func jsonText<T: Encodable>(_ value: T) throws -> String {
    let data = try encoder.encode(value)
    guard let text = String(data: data, encoding: .utf8) else {
      throw LiveMCPError.operationFailed("Could not encode JSON response.")
    }
    return text
  }
}

private struct OpenDecksResponse: Encodable {
  let documents: [OpenDocumentDescription]
}

private struct OpenDocumentDescription: Encodable {
  let documentID: String
  let name: String
  let path: String?
  let selectedSlideIndex: Int?
  let slideCount: Int

  @MainActor
  init(_ document: LiveMCPDocumentSession) {
    documentID = document.id.uuidString
    name = document.displayName
    path = document.fileURL()?.path
    selectedSlideIndex = document.selectedSlideIndex()
    slideCount = document.deck().slides.count
  }
}

private struct LiveDeckResponse: Encodable {
  let document: OpenDocumentDescription
  let deck: LiveDeckDescription
  let markdown: String?

  @MainActor
  init(document: LiveMCPDocumentSession, deck: PresentationDeck, markdown: String?) {
    self.document = OpenDocumentDescription(document)
    self.deck = LiveDeckDescription(deck)
    self.markdown = markdown
  }
}

private struct LiveMutationResponse: Encodable {
  let document: OpenDocumentDescription
  let message: String
  let deck: LiveDeckDescription

  @MainActor
  init(document: LiveMCPDocumentSession, message: String, deck: PresentationDeck) {
    self.document = OpenDocumentDescription(document)
    self.message = message
    self.deck = LiveDeckDescription(deck)
  }
}

private struct LiveValidationResponse: Encodable {
  let document: OpenDocumentDescription
  let valid: Bool
  let warnings: [String]
  let deck: LiveDeckDescription

  @MainActor
  init(document: LiveMCPDocumentSession, valid: Bool, warnings: [String], deck: PresentationDeck) {
    self.document = OpenDocumentDescription(document)
    self.valid = valid
    self.warnings = warnings
    self.deck = LiveDeckDescription(deck)
  }
}

private struct SelectionResponse: Encodable {
  let document: OpenDocumentDescription
  let selectedSlideIndex: Int?

  @MainActor
  init(document: LiveMCPDocumentSession) {
    self.document = OpenDocumentDescription(document)
    selectedSlideIndex = document.selectedSlideIndex()
  }
}

private struct LiveDeckDescription: Encodable {
  let theme: String
  let codex: LiveCodexSettingsDescription
  let slideCount: Int
  let slides: [LiveSlideDescription]

  init(_ deck: PresentationDeck) {
    theme = deck.settings.theme.rawValue
    codex = LiveCodexSettingsDescription(deck.settings.codex)
    slideCount = deck.slides.count
    slides = deck.slides.enumerated().map { LiveSlideDescription(index: $0.offset, slide: $0.element, includeMarkdown: false) }
  }
}

private struct LiveCodexSettingsDescription: Encodable {
  let model: String
  let reasoning: String
  let sandbox: String

  init(_ settings: DeckCodexSettings) {
    model = settings.model
    reasoning = settings.reasoning.rawValue
    sandbox = settings.sandbox
  }
}

private struct LiveSlideResponse: Encodable {
  let document: OpenDocumentDescription
  let index: Int
  let slide: LiveSlideDescription

  @MainActor
  init(document: LiveMCPDocumentSession, index: Int, slide: Slide) {
    self.document = OpenDocumentDescription(document)
    self.index = index
    self.slide = LiveSlideDescription(index: index, slide: slide, includeMarkdown: true)
  }
}

private struct LiveSlideDescription: Encodable {
  let index: Int
  let title: String
  let summary: String
  let codexBlockCount: Int
  let codexBlocks: [LiveCodexBlockDescription]
  let markdown: String?

  init(index: Int, slide: Slide, includeMarkdown: Bool) {
    self.index = index
    title = slide.title
    summary = slide.summary
    codexBlockCount = slide.codexBlocks.count
    codexBlocks = slide.codexBlocks.map(LiveCodexBlockDescription.init)
    markdown = includeMarkdown ? slide.markdown : nil
  }
}

private struct LiveCodexBlockDescription: Encodable {
  let id: String
  let title: String
  let model: String?
  let reasoning: String?
  let sandbox: String?

  init(_ block: CodexBlock) {
    id = block.id
    title = block.title
    model = block.model
    reasoning = block.reasoning?.rawValue
    sandbox = block.sandbox
  }
}

private func requiredString(_ arguments: [String: Any], _ key: String) throws -> String {
  guard let value = optionalString(arguments, key) else {
    throw LiveMCPError.invalidParams("Missing required string argument '\(key)'.")
  }
  return value
}

private func optionalString(_ arguments: [String: Any], _ key: String) -> String? {
  guard let value = arguments[key] as? String else { return nil }
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  return trimmed.isEmpty ? nil : value
}

private func requiredInt(_ arguments: [String: Any], _ key: String) throws -> Int {
  guard let value = try optionalInt(arguments, key) else {
    throw LiveMCPError.invalidParams("Missing required integer argument '\(key)'.")
  }
  return value
}

private func optionalInt(_ arguments: [String: Any], _ key: String) throws -> Int? {
  guard let value = arguments[key] else { return nil }
  if let int = value as? Int {
    return int
  }
  if let number = value as? NSNumber {
    return number.intValue
  }
  throw LiveMCPError.invalidParams("Argument '\(key)' must be an integer.")
}

private func requiredIndex(_ arguments: [String: Any], _ key: String, in range: Range<Int>) throws -> Int {
  let index = try requiredInt(arguments, key)
  guard range.contains(index) else {
    throw LiveMCPError.invalidParams("Index \(index) is outside the available slide range.")
  }
  return index
}

private func boundedInsertionIndex(_ index: Int, count: Int) throws -> Int {
  guard (0...count).contains(index) else {
    throw LiveMCPError.invalidParams("Insertion index \(index) must be between 0 and \(count).")
  }
  return index
}

private func validateCodexBlockID(_ value: String) throws {
  guard !value.contains(where: \.isWhitespace) else {
    throw LiveMCPError.invalidParams("Codex block id must not contain whitespace.")
  }
}

private func metadataValue(_ value: String) -> String {
  value
    .replacingOccurrences(of: "\r\n", with: " ")
    .replacingOccurrences(of: "\n", with: " ")
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func fenceMarker(for body: String) -> String {
  let longestRun = body
    .split(whereSeparator: { $0 != "`" })
    .map(\.count)
    .max() ?? 0
  return String(repeating: "`", count: max(3, longestRun + 1))
}

private func tool(_ name: String, _ description: String, properties: [String: Any] = [:], required: [String] = []) -> [String: Any] {
  [
    "name": name,
    "description": description,
    "inputSchema": [
      "type": "object",
      "properties": properties,
      "required": required
    ]
  ]
}

private func stringSchema(_ description: String) -> [String: Any] {
  ["type": "string", "description": description]
}

private func integerSchema(_ description: String) -> [String: Any] {
  ["type": "integer", "description": description]
}

private func enumSchema(_ values: [String]) -> [String: Any] {
  ["type": "string", "enum": values]
}
