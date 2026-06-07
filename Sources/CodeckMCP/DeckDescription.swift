import CodeckCore
import Foundation

struct DeckDescription: Encodable {
  let theme: String
  let codex: CodexSettingsDescription
  let slideCount: Int
  let slides: [SlideDescription]

  init(_ deck: PresentationDeck) {
    theme = deck.settings.theme.rawValue
    codex = CodexSettingsDescription(deck.settings.codex)
    slideCount = deck.slides.count
    slides = deck.slides.enumerated().map { SlideDescription(index: $0.offset, slide: $0.element, includeMarkdown: false) }
  }
}
