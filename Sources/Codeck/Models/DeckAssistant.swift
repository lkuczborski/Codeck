import CodeckCore
import Foundation

enum DeckAssistantScope: String, CaseIterable, Identifiable, Hashable {
  case currentSlide
  case wholeDeck

  var id: String { rawValue }

  var title: String {
    switch self {
    case .currentSlide:
      "Slide"
    case .wholeDeck:
      "Deck"
    }
  }

  var systemImage: String {
    switch self {
    case .currentSlide:
      "rectangle"
    case .wholeDeck:
      "rectangle.stack"
    }
  }

  var promptInstruction: String {
    switch self {
    case .currentSlide:
      "Prioritize the selected slide. You may insert one supporting slide only if it is clearly needed."
    case .wholeDeck:
      "Audit the whole presentation and propose the smallest set of high-impact deck-level improvements."
    }
  }
}

enum DeckAssistantQuickAction: String, CaseIterable, Identifiable, Hashable {
  case diagnose
  case shorten
  case professionalize
  case addResearch
  case addData

  var id: String { rawValue }

  var title: String {
    switch self {
    case .diagnose:
      "Find Gaps"
    case .shorten:
      "Shorten"
    case .professionalize:
      "Polish"
    case .addResearch:
      "Research"
    case .addData:
      "Add Data"
    }
  }

  var systemImage: String {
    switch self {
    case .diagnose:
      "sparkle.magnifyingglass"
    case .shorten:
      "scissors"
    case .professionalize:
      "briefcase"
    case .addResearch:
      "globe"
    case .addData:
      "chart.bar.doc.horizontal"
    }
  }

  var prompt: String {
    switch self {
    case .diagnose:
      "Check what is missing, unclear, unsupported, or too weak for the audience. Propose concrete slide edits."
    case .shorten:
      "Make this tighter and easier to present. Remove filler, reduce cognitive load, and keep the strongest message."
    case .professionalize:
      "Make the presentation more professional, precise, and executive-ready without making it bland."
    case .addResearch:
      "Improve the presentation with relevant current context and cite trustworthy sources when you use external facts."
    case .addData:
      "Add useful data, benchmarks, comparisons, or evidence that would strengthen the argument. Cite sources when external facts are used."
    }
  }

  var requiresWebResearch: Bool {
    switch self {
    case .addResearch, .addData:
      true
    case .diagnose, .shorten, .professionalize:
      false
    }
  }
}

enum DeckAssistantRunPolicy {
  static func canRun(
    _ action: DeckAssistantQuickAction,
    allowsWebResearch: Bool,
    isRunning: Bool
  ) -> Bool {
    guard !isRunning else { return false }
    return allowsWebResearch || !action.requiresWebResearch
  }
}

struct DeckAssistantDeckContextCache: Hashable {
  private(set) var fingerprint = ""
  private(set) var outline = ""

  mutating func outline(for deck: PresentationDeck) -> String {
    let nextFingerprint = Self.fingerprint(for: deck)
    guard nextFingerprint != fingerprint else { return outline }

    fingerprint = nextFingerprint
    outline = Self.makeOutline(for: deck)
    return outline
  }

  static func makeOutline(for deck: PresentationDeck) -> String {
    guard !deck.slides.isEmpty else { return "No slides." }

    return deck.slides.enumerated().map { index, slide in
      let summary = slide.summary.trimmingCharacters(in: .whitespacesAndNewlines)
      let detail = summary.isEmpty ? "No summary." : summary
      return "\(index). \(slide.title) - \(detail)"
    }
    .joined(separator: "\n")
  }

  private static func fingerprint(for deck: PresentationDeck) -> String {
    deck.slides.map { slide in
      "\(slide.id.uuidString)|\(slide.markdown)"
    }
    .joined(separator: "\n")
  }
}

struct DeckAssistantProposal: Identifiable, Hashable {
  let id: UUID
  var title: String
  var summary: String
  var changes: [DeckAssistantChange]

  init(
    id: UUID = UUID(),
    title: String,
    summary: String,
    changes: [DeckAssistantChange]
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.changes = changes
  }

  static let empty = DeckAssistantProposal(
    title: "No proposal yet",
    summary: "Ask Codex to review the current slide or the full deck.",
    changes: []
  )
}

struct DeckAssistantChange: Identifiable, Hashable {
  enum Operation: Hashable {
    case insert(position: Int)
    case replace(index: Int)
  }

  let id: String
  var title: String
  var detail: String
  var operation: Operation
  var beforeMarkdown: String?
  var afterMarkdown: String

  var locationLabel: String {
    switch operation {
    case .insert(let position):
      "Insert at \(position + 1)"
    case .replace(let index):
      "Slide \(index + 1)"
    }
  }
}

enum DeckAssistantPromptBuilder {
  static func prompt(
    goal: String,
    scope: DeckAssistantScope,
    allowsWebResearch: Bool,
    deck: PresentationDeck,
    selectedSlideIndex: Int?,
    deckOutline: String? = nil,
    currentDate: Date = Date()
  ) -> String {
    let selectedIndex = resolvedSelectedIndex(in: deck, selectedSlideIndex: selectedSlideIndex)
    let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
    let effectiveGoal = trimmedGoal.isEmpty
      ? DeckAssistantQuickAction.diagnose.prompt
      : trimmedGoal
    let currentDateString = ISO8601DateFormatter().string(from: currentDate)
    let deckOutline = deckOutline ?? DeckAssistantDeckContextCache.makeOutline(for: deck)
    let context = deckContext(
      deck,
      scope: scope,
      selectedIndex: selectedIndex
    )

    return """
    You are Codeck's interactive presentation assistant. You are running inside a Markdown slide editor.

    Your job:
    - Read the deck outline, selected slide, and any included supporting slide markdown.
    - Decide what is missing, weak, too long, unsupported, or unclear.
    - Propose concrete slide edits that improve the presentation.
    - Keep the user's intent and existing voice unless the user asks for a different tone.

    User request:
    \(effectiveGoal)

    Scope:
    \(scope.promptInstruction)

    Response mode:
    Run a fast targeted pass. Prefer the selected slide, deck outline, and nearby slide context over broad deck rewrites.

    Current date:
    \(currentDateString)

    Web research:
    \(allowsWebResearch ? "Enabled. Use current web context when it materially improves factual quality. Cite URLs in the slide markdown for external facts. Do not invent sources." : "Disabled. Use only the deck context below. Do not browse, search, fetch URLs, or claim that you checked the web.")

    Editing rules:
    - Return 1 to 5 changes.
    - Use "replace" to rewrite an existing slide.
    - Use "insert" to add a new slide.
    - Each afterMarkdown value must be the complete Markdown for exactly one slide.
    - Preserve runnable ```codex fences when they remain useful.
    - Do not return YAML front matter.
    - Do not delete slides directly. If a slide should go away, replace it with a tighter version or explain it in detail.
    - Prefer fewer, stronger edits over broad churn.

    Return only JSON. No prose before or after the JSON. Use this exact schema:
    {
      "title": "Short proposal title",
      "summary": "One sentence explaining the improvement",
      "changes": [
        {
          "id": "stable-kebab-id",
          "title": "Change title",
          "detail": "Why this change helps",
          "operation": "replace",
          "slideIndex": 0,
          "afterMarkdown": "# Complete replacement slide markdown"
        },
        {
          "id": "stable-kebab-id",
          "title": "Change title",
          "detail": "Why this change helps",
          "operation": "insert",
          "insertPosition": 1,
          "afterMarkdown": "# Complete inserted slide markdown"
        }
      ]
    }

    Indexing:
    - slideIndex is zero-based.
    - insertPosition is zero-based and means "insert before this slide index". Use \(deck.slides.count) to append.

    Selected slide:
    \(selectedSlideDescription(in: deck, selectedIndex: selectedIndex))

    Deck outline:
    \(deckOutline)

    \(context.title):
    \(context.body)
    """
  }

  private static func resolvedSelectedIndex(in deck: PresentationDeck, selectedSlideIndex: Int?) -> Int? {
    guard !deck.slides.isEmpty else { return nil }
    guard let selectedSlideIndex else { return deck.slides.startIndex }
    return min(max(selectedSlideIndex, deck.slides.startIndex), deck.slides.count - 1)
  }

  private static func selectedSlideDescription(in deck: PresentationDeck, selectedIndex: Int?) -> String {
    guard let selectedIndex, deck.slides.indices.contains(selectedIndex) else {
      return "None"
    }

    let slide = deck.slides[selectedIndex]
    return """
    index: \(selectedIndex)
    title: \(slide.title)
    markdown:
    ~~~~markdown
    \(slide.markdown)
    ~~~~
    """
  }

  private static func deckContext(
    _ deck: PresentationDeck,
    scope: DeckAssistantScope,
    selectedIndex: Int?
  ) -> (title: String, body: String) {
    switch scope {
    case .currentSlide:
      return ("Nearby slide context", nearbySlideContext(deck, selectedIndex: selectedIndex))
    case .wholeDeck:
      return ("Full deck", fullDeckContext(deck))
    }
  }

  private static func nearbySlideContext(_ deck: PresentationDeck, selectedIndex: Int?) -> String {
    guard let selectedIndex else { return "None" }

    let nearbyIndices = [selectedIndex - 1, selectedIndex + 1]
      .filter { deck.slides.indices.contains($0) }

    guard !nearbyIndices.isEmpty else {
      return "No adjacent slides."
    }

    return nearbyIndices.map { index in
      slideContext(index: index, slide: deck.slides[index])
    }
    .joined(separator: "\n\n")
  }

  private static func fullDeckContext(_ deck: PresentationDeck) -> String {
    deck.slides.enumerated().map { index, slide in
      slideContext(index: index, slide: slide)
    }
    .joined(separator: "\n\n")
  }

  private static func slideContext(index: Int, slide: Slide) -> String {
    """
    <slide index="\(index)" title="\(escapeAttribute(slide.title))">
    ~~~~markdown
    \(slide.markdown)
    ~~~~
    </slide>
    """
  }

  private static func escapeAttribute(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}

enum DeckAssistantProposalParser {
  enum ParseError: LocalizedError, Equatable {
    case missingJSONObject
    case invalidJSON(String)
    case noValidChanges

    var errorDescription: String? {
      switch self {
      case .missingJSONObject:
        "Codex did not return a JSON proposal."
      case .invalidJSON(let message):
        "Codex returned JSON that could not be parsed: \(message)"
      case .noValidChanges:
        "Codex returned a proposal, but none of the changes matched the current deck."
      }
    }
  }

  static func proposal(from text: String, deck: PresentationDeck) throws -> DeckAssistantProposal {
    let json = try extractJSONObject(from: text)
    let data = Data(json.utf8)
    let payload: ProposalPayload

    do {
      payload = try JSONDecoder().decode(ProposalPayload.self, from: data)
    } catch {
      throw ParseError.invalidJSON(error.localizedDescription)
    }

    let changes = payload.changes.enumerated().compactMap { offset, payloadChange in
      change(from: payloadChange, offset: offset, deck: deck)
    }

    guard !changes.isEmpty else {
      throw ParseError.noValidChanges
    }

    return DeckAssistantProposal(
      title: nonEmpty(payload.title) ?? "Codex proposal",
      summary: nonEmpty(payload.summary) ?? "\(changes.count) proposed change\(changes.count == 1 ? "" : "s").",
      changes: changes
    )
  }

  private struct ProposalPayload: Decodable {
    var title: String?
    var summary: String?
    var changes: [ChangePayload]
  }

  private struct ChangePayload: Decodable {
    var id: String?
    var title: String?
    var detail: String?
    var operation: String
    var slideIndex: Int?
    var insertPosition: Int?
    var afterMarkdown: String
  }

  private static func change(from payload: ChangePayload, offset: Int, deck: PresentationDeck) -> DeckAssistantChange? {
    let afterMarkdown = payload.afterMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !afterMarkdown.isEmpty else { return nil }

    let operationName = payload.operation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let operation: DeckAssistantChange.Operation
    let beforeMarkdown: String?

    switch operationName {
    case "replace":
      guard let index = normalizedSlideIndex(payload.slideIndex, in: deck) else {
        return nil
      }
      operation = .replace(index: index)
      beforeMarkdown = deck.slides[index].markdown
    case "insert":
      operation = .insert(position: normalizedInsertPosition(payload.insertPosition ?? payload.slideIndex, in: deck))
      beforeMarkdown = nil
    default:
      return nil
    }

    return DeckAssistantChange(
      id: stableID(payload.id, fallback: "assistant-change-\(offset)"),
      title: nonEmpty(payload.title) ?? defaultTitle(for: operation),
      detail: nonEmpty(payload.detail) ?? "Codex proposed this change from the deck context.",
      operation: operation,
      beforeMarkdown: beforeMarkdown,
      afterMarkdown: afterMarkdown
    )
  }

  private static func normalizedSlideIndex(_ value: Int?, in deck: PresentationDeck) -> Int? {
    guard let value else { return nil }
    if deck.slides.indices.contains(value) {
      return value
    }

    let oneBased = value - 1
    if deck.slides.indices.contains(oneBased) {
      return oneBased
    }

    return nil
  }

  private static func normalizedInsertPosition(_ value: Int?, in deck: PresentationDeck) -> Int {
    guard let value else { return deck.slides.count }
    if (0...deck.slides.count).contains(value) {
      return value
    }

    let oneBased = value - 1
    if (0...deck.slides.count).contains(oneBased) {
      return oneBased
    }

    return min(max(value, 0), deck.slides.count)
  }

  private static func defaultTitle(for operation: DeckAssistantChange.Operation) -> String {
    switch operation {
    case .insert:
      "Insert slide"
    case .replace(let index):
      "Rewrite slide \(index + 1)"
    }
  }

  private static func stableID(_ value: String?, fallback: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let filtered = String(trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    let collapsed = filtered
      .split(separator: "-")
      .joined(separator: "-")
      .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
    return collapsed.isEmpty ? fallback : collapsed
  }

  private static func extractJSONObject(from text: String) throws -> String {
    if let fencedJSON = extractFencedJSON(from: text) {
      return fencedJSON
    }

    if let object = extractBalancedJSONObject(from: text) {
      return object
    }

    throw ParseError.missingJSONObject
  }

  private static func extractFencedJSON(from text: String) -> String? {
    for marker in ["```json", "```JSON", "```"] {
      guard let start = text.range(of: marker) else { continue }
      let remainder = text[start.upperBound...]
      guard let end = remainder.range(of: "```") else { continue }
      let candidate = String(remainder[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
      if candidate.first == "{" {
        return candidate
      }
    }

    return nil
  }

  private static func extractBalancedJSONObject(from text: String) -> String? {
    var startIndex: String.Index?
    var depth = 0
    var isInsideString = false
    var isEscaped = false

    for index in text.indices {
      let character = text[index]

      if startIndex == nil {
        guard character == "{" else { continue }
        startIndex = index
        depth = 1
        continue
      }

      if isInsideString {
        if isEscaped {
          isEscaped = false
        } else if character == "\\" {
          isEscaped = true
        } else if character == "\"" {
          isInsideString = false
        }
        continue
      }

      if character == "\"" {
        isInsideString = true
      } else if character == "{" {
        depth += 1
      } else if character == "}" {
        depth -= 1
        if depth == 0, let startIndex {
          return String(text[startIndex...index])
        }
      }
    }

    return nil
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }
}
