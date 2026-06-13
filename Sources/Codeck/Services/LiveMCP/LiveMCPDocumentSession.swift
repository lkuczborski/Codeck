import CodeckCore
import Foundation

@MainActor
struct LiveMCPDocumentSession {
    let id: UUID
    let fileURL: () -> URL?
    let deck: () -> PresentationDeck
    let setDeck: (PresentationDeck) -> Void
    let selectedSlideIndex: () -> Int?
    let selectSlide: (Int) -> Void
    let present: () -> Void
    let dismissPresentation: () -> Void

    var displayName: String {
        if let fileURL = fileURL() {
            return fileURL.lastPathComponent
        }
        return deck().slides.first?.title ?? "Untitled Deck"
    }
}
