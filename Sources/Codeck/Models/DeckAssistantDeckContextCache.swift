import CodeckCore
import Foundation

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
