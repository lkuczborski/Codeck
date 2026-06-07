import CodeckCore
import Foundation

final class CodeckMCPServer {
  private let store = CodeckDeckFileStore()
  private let paths = PathAccessGuard.fromEnvironment()
  private let requestDecoder = JSONDecoder()
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return encoder
  }()

  func run() {
    while let line = readLine(strippingNewline: true) {
      guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        continue
      }

      do {
        let data = Data(line.utf8)
        let message = try JSONSerialization.jsonObject(with: data)
        if let batch = message as? [[String: Any]] {
          let envelopes = try requestDecoder.decode([JSONRPCMessageEnvelope].self, from: data)
          let responses = zip(batch, envelopes).compactMap { message, envelope in
            handleMessage(message, envelope: envelope)
          }
          if !responses.isEmpty {
            writeJSON(responses)
          }
        } else if let object = message as? [String: Any] {
          let envelope = try requestDecoder.decode(JSONRPCMessageEnvelope.self, from: data)
          if let response = handleMessage(object, envelope: envelope) {
            writeJSON(response)
          }
        } else {
          writeJSON(errorResponse(id: nil, code: -32600, message: "Invalid JSON-RPC message."))
        }
      } catch {
        writeJSON(errorResponse(id: nil, code: -32700, message: "Parse error: \(error.localizedDescription)"))
      }
    }
  }

  private func handleMessage(_ message: [String: Any], envelope: JSONRPCMessageEnvelope) -> [String: Any]? {
    guard let method = envelope.method else {
      return errorResponse(id: envelope.responseID, code: -32600, message: "Missing method.")
    }

    guard case let .valid(id) = envelope.idState else {
      if case .invalid = envelope.idState {
        return errorResponse(id: nil, code: -32600, message: "Invalid JSON-RPC request id.")
      }
      return nil
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
        return try response(id: id, result: callToolResult(params: dictionaryParams(message["params"])))
      case "resources/list":
        return response(id: id, result: ["resources": []])
      case "resources/templates/list":
        return response(id: id, result: ["resourceTemplates": resourceTemplates])
      case "resources/read":
        return try response(id: id, result: readResourceResult(params: dictionaryParams(message["params"])))
      default:
        return errorResponse(id: id, code: -32601, message: "Unknown method: \(method)")
      }
    } catch let error as CodeckMCPError {
      return errorResponse(id: id, code: error.jsonRPCCode, message: error.localizedDescription)
    } catch {
      return errorResponse(id: id, code: -32603, message: error.localizedDescription)
    }
  }

  private func initializeResult(params: [String: Any]?) -> [String: Any] {
    let protocolVersion = params?["protocolVersion"] as? String ?? "2025-11-25"
    return [
      "protocolVersion": protocolVersion,
      "capabilities": [
        "tools": ["listChanged": false],
        "resources": ["listChanged": false],
      ],
      "serverInfo": [
        "name": "codeck-mcp",
        "version": "0.1.0",
      ],
      "instructions": """
      Create and edit Codeck .mdeck Markdown presentation decks. Use zero-based slide indexes; slide UUIDs are runtime-only and are not persisted in .mdeck files.
      """,
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
    case "create_deck":
      return try createDeck(arguments)
    case "read_deck":
      return try readDeck(arguments)
    case "list_slides":
      return try listSlides(arguments)
    case "get_slide":
      return try getSlide(arguments)
    case "set_slide_markdown":
      return try setSlideMarkdown(arguments)
    case "insert_slide":
      return try insertSlide(arguments)
    case "delete_slide":
      return try deleteSlide(arguments)
    case "move_slide":
      return try moveSlide(arguments)
    case "duplicate_slide":
      return try duplicateSlide(arguments)
    case "set_deck_settings":
      return try setDeckSettings(arguments)
    case "insert_codex_block":
      return try insertCodexBlock(arguments)
    case "validate_deck":
      return try validateDeck(arguments)
    default:
      throw CodeckMCPError.invalidParams("Unknown tool: \(name)")
    }
  }

  private func createDeck(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    let title = optionalString(arguments, "title")
    let theme = try optionalTheme(arguments) ?? .studio
    let overwrite = optionalBool(arguments, "overwrite") ?? false
    let createDirectories = optionalBool(arguments, "create_directories") ?? false
    let slideMarkdown = try optionalStringArray(arguments, "slides") ?? title.map { ["# \($0)"] } ?? []
    let settings = PresentationSettings(
      theme: theme,
      codex: DeckCodexSettings(
        model: optionalString(arguments, "model") ?? DeckCodexSettings.default.model,
        reasoning: optionalString(arguments, "reasoning").map(CodexReasoningEffort.init(rawValue:)) ?? DeckCodexSettings.default.reasoning,
        sandbox: optionalString(arguments, "sandbox") ?? DeckCodexSettings.default.sandbox
      )
    )
    let deck = try store.createDeck(
      at: url,
      settings: settings,
      slideMarkdown: slideMarkdown,
      overwrite: overwrite,
      createDirectories: createDirectories
    )
    return try jsonText(DeckResponse(path: url.path, deck: DeckDescription(deck), markdown: deck.deckDocument))
  }

  private func readDeck(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    let deck = try store.loadDeck(at: url)
    return try jsonText(DeckResponse(path: url.path, deck: DeckDescription(deck), markdown: deck.deckDocument))
  }

  private func listSlides(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    let deck = try store.loadDeck(at: url)
    return try jsonText(DeckResponse(path: url.path, deck: DeckDescription(deck), markdown: nil))
  }

  private func getSlide(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    let deck = try store.loadDeck(at: url)
    let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
    return try jsonText(SlideResponse(path: url.path, index: index, slide: deck.slides[index]))
  }

  private func setSlideMarkdown(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    var deck = try store.loadDeck(at: url)
    let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
    let markdown = try requiredString(arguments, "markdown")
    let slideID = deck.slides[index].id
    let replacement = deck.replaceSlideMarkdown(for: slideID, with: markdown)
    try store.saveDeck(deck, at: url)
    return try jsonText(
      MutationResponse(
        path: url.path,
        message: replacement?.didSplit == true ? "Slide updated and split into multiple slides." : "Slide updated.",
        deck: DeckDescription(deck)
      )
    )
  }

  private func insertSlide(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    var deck = try store.loadDeck(at: url)
    let markdown = optionalString(arguments, "markdown") ?? PresentationDeck.defaultSlideMarkdown
    let position = try optionalInt(arguments, "position").map { try boundedInsertionIndex($0, count: deck.slides.count) } ?? deck.slides.count
    deck.slides.insert(Slide(markdown: markdown), at: position)
    try store.saveDeck(deck, at: url)
    return try jsonText(MutationResponse(path: url.path, message: "Slide inserted at index \(position).", deck: DeckDescription(deck)))
  }

  private func deleteSlide(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    var deck = try store.loadDeck(at: url)
    guard deck.slides.count > 1 else {
      throw CodeckMCPError.operationFailed("A Codeck deck must keep at least one slide.")
    }
    let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
    deck.slides.remove(at: index)
    try store.saveDeck(deck, at: url)
    return try jsonText(MutationResponse(path: url.path, message: "Slide \(index) deleted.", deck: DeckDescription(deck)))
  }

  private func moveSlide(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    var deck = try store.loadDeck(at: url)
    let fromIndex = try requiredIndex(arguments, "from_index", in: deck.slides.indices)
    let toIndex = try boundedInsertionIndex(requiredInt(arguments, "to_index"), count: deck.slides.count)
    let slide = deck.slides.remove(at: fromIndex)
    let adjustedDestination = min(toIndex, deck.slides.count)
    deck.slides.insert(slide, at: adjustedDestination)
    try store.saveDeck(deck, at: url)
    return try jsonText(
      MutationResponse(
        path: url.path,
        message: "Slide moved from \(fromIndex) to \(adjustedDestination).",
        deck: DeckDescription(deck)
      )
    )
  }

  private func duplicateSlide(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    var deck = try store.loadDeck(at: url)
    let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
    deck.slides.insert(Slide(markdown: deck.slides[index].markdown), at: index + 1)
    try store.saveDeck(deck, at: url)
    return try jsonText(MutationResponse(path: url.path, message: "Slide \(index) duplicated.", deck: DeckDescription(deck)))
  }

  private func setDeckSettings(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    var deck = try store.loadDeck(at: url)
    if let theme = try optionalTheme(arguments) {
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
    try store.saveDeck(deck, at: url)
    return try jsonText(MutationResponse(path: url.path, message: "Deck settings updated.", deck: DeckDescription(deck)))
  }

  private func insertCodexBlock(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    var deck = try store.loadDeck(at: url)
    let index = try requiredIndex(arguments, "index", in: deck.slides.indices)
    let prompt = optionalString(arguments, "prompt") ?? "Explain this concept with one concrete example."
    let blockID = optionalString(arguments, "id") ?? "demo-\(deck.slides[index].codexBlocks.count + 1)"
    try validateCodexBlockID(blockID)

    var metadata = [
      "title: \(metadataValue(optionalString(arguments, "title") ?? "Describe the goal for this prompt"))",
    ]
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
    try store.saveDeck(deck, at: url)
    return try jsonText(MutationResponse(path: url.path, message: "Codex block inserted into slide \(index).", deck: DeckDescription(deck)))
  }

  private func validateDeck(_ arguments: [String: Any]) throws -> String {
    let url = try deckURL(from: arguments)
    let deck = try store.loadDeck(at: url)
    return try jsonText(ValidationResponse(path: url.path, valid: true, warnings: [], deck: DeckDescription(deck)))
  }

  private func readResourceResult(params: [String: Any]) throws -> [String: Any] {
    guard let uri = params["uri"] as? String else {
      throw CodeckMCPError.invalidParams("Missing resource uri.")
    }
    let resource = try resourceContent(for: uri)
    return [
      "contents": [
        [
          "uri": uri,
          "mimeType": resource.mimeType,
          "text": resource.text,
        ],
      ],
    ]
  }

  private func resourceContent(for uri: String) throws -> (mimeType: String, text: String) {
    guard let components = URLComponents(string: uri),
          components.scheme == "codeck",
          components.host == "file",
          components.path == "/deck"
    else {
      throw CodeckMCPError.invalidParams("Unsupported resource URI. Use codeck://file/deck?path=<deck>&view=document|outline|slide.")
    }

    let query = (components.queryItems ?? []).reduce(into: [String: String]()) { result, item in
      if let value = item.value {
        result[item.name] = value
      }
    }
    guard let path = query["path"] else {
      throw CodeckMCPError.invalidParams("Resource URI is missing the path query item.")
    }

    let url = try paths.resolve(path)
    let deck = try store.loadDeck(at: url)
    switch query["view"] ?? "outline" {
    case "document":
      return ("text/markdown", deck.deckDocument)
    case "outline":
      return try ("application/json", jsonText(DeckResponse(path: url.path, deck: DeckDescription(deck), markdown: nil)))
    case "slide":
      guard let rawIndex = query["index"], let index = Int(rawIndex), deck.slides.indices.contains(index) else {
        throw CodeckMCPError.invalidParams("Slide resources require a valid index query item.")
      }
      return try ("application/json", jsonText(SlideResponse(path: url.path, index: index, slide: deck.slides[index])))
    default:
      throw CodeckMCPError.invalidParams("Unsupported resource view.")
    }
  }

  private var tools: [[String: Any]] {
    [
      tool(
        "create_deck",
        "Create a Codeck .mdeck file.",
        properties: [
          "path": stringSchema("Deck path, absolute or relative to the server working directory."),
          "title": stringSchema("Optional first-slide title used when slides is omitted."),
          "theme": enumSchema(PresentationTheme.allCases.map(\.rawValue)),
          "slides": arraySchema(items: stringSchema("Slide Markdown.")),
          "overwrite": booleanSchema("Replace an existing file."),
          "create_directories": booleanSchema("Create missing parent directories."),
          "model": stringSchema("Deck-level Codex model."),
          "reasoning": stringSchema("Deck-level Codex reasoning effort."),
          "sandbox": stringSchema("Deck-level Codex sandbox."),
        ],
        required: ["path"]
      ),
      tool("read_deck", "Read a Codeck deck as Markdown plus structured outline.", properties: pathProperties, required: ["path"]),
      tool("list_slides", "Return slide titles, summaries, and Codex block counts.", properties: pathProperties, required: ["path"]),
      tool(
        "get_slide",
        "Read one slide by zero-based index.",
        properties: pathProperties.merging(["index": integerSchema("Zero-based slide index.")]) { _, new in new },
        required: ["path", "index"]
      ),
      tool(
        "set_slide_markdown",
        "Replace one slide's Markdown. If the Markdown contains slide separators, Codeck splits it into slides.",
        properties: pathProperties.merging([
          "index": integerSchema("Zero-based slide index."),
          "markdown": stringSchema("Replacement slide Markdown."),
        ]) { _, new in new },
        required: ["path", "index", "markdown"]
      ),
      tool(
        "insert_slide",
        "Insert a slide at position, or append when omitted.",
        properties: pathProperties.merging([
          "position": integerSchema("Zero-based insertion position from 0 through slide count."),
          "markdown": stringSchema("New slide Markdown."),
        ]) { _, new in new },
        required: ["path"]
      ),
      tool(
        "delete_slide",
        "Delete a slide by zero-based index.",
        properties: pathProperties.merging(["index": integerSchema("Zero-based slide index.")]) { _, new in new },
        required: ["path", "index"]
      ),
      tool(
        "move_slide",
        "Move a slide. to_index is the insertion index after removing the slide.",
        properties: pathProperties.merging([
          "from_index": integerSchema("Current zero-based slide index."),
          "to_index": integerSchema("Destination insertion index."),
        ]) { _, new in new },
        required: ["path", "from_index", "to_index"]
      ),
      tool(
        "duplicate_slide",
        "Duplicate a slide immediately after itself.",
        properties: pathProperties.merging(["index": integerSchema("Zero-based slide index.")]) { _, new in new },
        required: ["path", "index"]
      ),
      tool(
        "set_deck_settings",
        "Update deck theme or deck-level Codex defaults.",
        properties: pathProperties.merging([
          "theme": enumSchema(PresentationTheme.allCases.map(\.rawValue)),
          "model": stringSchema("Deck-level Codex model."),
          "reasoning": stringSchema("Deck-level Codex reasoning effort."),
          "sandbox": stringSchema("Deck-level Codex sandbox."),
        ]) { _, new in new },
        required: ["path"]
      ),
      tool(
        "insert_codex_block",
        "Append a runnable Codex block to a slide.",
        properties: pathProperties.merging([
          "index": integerSchema("Zero-based slide index."),
          "id": stringSchema("Optional block id. Must not contain whitespace."),
          "title": stringSchema("Human-readable Codex card title."),
          "prompt": stringSchema("Prompt body for the Codex block."),
          "model": stringSchema("Optional block-level model override."),
          "reasoning": stringSchema("Optional block-level reasoning override."),
          "sandbox": stringSchema("Optional block-level sandbox override."),
        ]) { _, new in new },
        required: ["path", "index"]
      ),
      tool("validate_deck", "Parse a deck and return validation status plus outline.", properties: pathProperties, required: ["path"]),
    ]
  }

  private var pathProperties: [String: Any] {
    ["path": stringSchema("Deck path, absolute or relative to the server working directory.")]
  }

  private var resourceTemplates: [[String: Any]] {
    [
      [
        "name": "Codeck deck",
        "description": "Read a deck document, outline, or slide. Use view=document, view=outline, or view=slide with index.",
        "uriTemplate": "codeck://file/deck{?path,view,index}",
      ],
    ]
  }

  private func deckURL(from arguments: [String: Any]) throws -> URL {
    try paths.resolve(requiredString(arguments, "path"))
  }

  private func optionalTheme(_ arguments: [String: Any]) throws -> PresentationTheme? {
    guard let rawValue = optionalString(arguments, "theme") else { return nil }
    guard let theme = PresentationTheme(rawValue: rawValue) else {
      throw CodeckMCPError.invalidParams("Unsupported theme '\(rawValue)'.")
    }
    return theme
  }

  private func requiredIndex(_ arguments: [String: Any], _ key: String, in range: Range<Int>) throws -> Int {
    let index = try requiredInt(arguments, key)
    guard range.contains(index) else {
      throw CodeckMCPError.invalidParams("Index \(index) is outside the available slide range.")
    }
    return index
  }

  private func boundedInsertionIndex(_ index: Int, count: Int) throws -> Int {
    guard (0 ... count).contains(index) else {
      throw CodeckMCPError.invalidParams("Insertion index \(index) must be between 0 and \(count).")
    }
    return index
  }

  private func jsonText(_ value: some Encodable) throws -> String {
    let data = try encoder.encode(value)
    guard let text = String(data: data, encoding: .utf8) else {
      throw CodeckMCPError.operationFailed("Could not encode JSON response.")
    }
    return text
  }

  private func dictionaryParams(_ value: Any?) throws -> [String: Any] {
    guard let params = value as? [String: Any] else {
      throw CodeckMCPError.invalidParams("Expected object params.")
    }
    return params
  }

  private func response(id: JSONRPCRequestID, result: [String: Any]) -> [String: Any] {
    ["jsonrpc": "2.0", "id": id.jsonValue, "result": result]
  }

  private func errorResponse(id: JSONRPCRequestID?, code: Int, message: String) -> [String: Any] {
    var response: [String: Any] = [
      "jsonrpc": "2.0",
      "error": [
        "code": code,
        "message": message,
      ],
    ]
    if let id {
      response["id"] = id.jsonValue
    }
    return response
  }

  private func toolError(_ message: String) -> [String: Any] {
    ["content": [["type": "text", "text": message]], "isError": true]
  }

  private func writeJSON(_ object: Any) {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    else {
      return
    }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
  }
}
