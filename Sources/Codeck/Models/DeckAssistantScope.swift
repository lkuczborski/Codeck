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
