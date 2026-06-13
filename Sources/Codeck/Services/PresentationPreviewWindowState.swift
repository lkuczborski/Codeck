import AppKit
import CodeckCore
import SwiftUI

@MainActor
final class PresentationPreviewWindowState: ObservableObject {
    @Published var deck: PresentationDeck = .blank
    @Published var selectedSlideID: Slide.ID?
    @Published var fallbackSlideIndex: Int?
    @Published var baseURL: URL?

    func update(deck: PresentationDeck, selectedSlideID: Slide.ID?, baseURL: URL?) {
        let didChangeSelection = self.selectedSlideID != selectedSlideID
        self.deck = deck
        self.selectedSlideID = selectedSlideID
        self.baseURL = baseURL

        if didChangeSelection {
            fallbackSlideIndex = nil
        } else {
            fallbackSlideIndex = clampedSlideIndex(fallbackSlideIndex)
        }
    }

    func clampedSlideIndex(_ index: Int?) -> Int? {
        guard let index, deck.slides.indices.contains(index) else { return nil }
        return index
    }
}
