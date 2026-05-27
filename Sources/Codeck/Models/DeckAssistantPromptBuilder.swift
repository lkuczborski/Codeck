import CodeckCore
import Foundation

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
    Run a targeted pass. Prefer the selected slide, deck outline, and nearby slide context over broad deck rewrites.

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
