import CodeckCore
import Foundation

struct LiveDeckDescription: Encodable {
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
