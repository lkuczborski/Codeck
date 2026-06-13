import CodeckCore
import SwiftUI

struct SlideCommandActions {
    let document: Binding<PresentationDocument>
    let selectedSlideIDString: Binding<String?>
    var presentTemplatePicker: (() -> Void)?

    var canDuplicateSlide: Bool {
        resolvedSelectedSlideID(in: document.wrappedValue.deck) != nil
    }

    var canShowTemplatePicker: Bool {
        presentTemplatePicker != nil
    }

    func addSlide(markdown: String = PresentationDeck.defaultSlideMarkdown) {
        var deck = document.wrappedValue.deck
        let newID = deck.addSlide(after: resolvedSelectedSlideID(in: deck), markdown: markdown)
        document.wrappedValue.deck = deck
        setSelectedSlideID(newID)
    }

    func addSlide(from template: SlideTemplate) {
        addSlide(markdown: template.markdown)
    }

    func duplicateSlide() {
        var deck = document.wrappedValue.deck
        guard let newID = deck.duplicateSlide(resolvedSelectedSlideID(in: deck)) else {
            return
        }

        document.wrappedValue.deck = deck
        setSelectedSlideID(newID)
    }

    func showTemplatePicker() {
        presentTemplatePicker?()
    }

    var selectedSlideID: Slide.ID? {
        selectedSlideIDString.wrappedValue.flatMap(UUID.init(uuidString:))
    }

    private func resolvedSelectedSlideID(in deck: PresentationDeck) -> Slide.ID? {
        if let selectedSlideID, deck.slides.contains(where: { $0.id == selectedSlideID }) {
            return selectedSlideID
        }

        return deck.slides.first?.id
    }

    private func setSelectedSlideID(_ id: Slide.ID?) {
        selectedSlideIDString.wrappedValue = id?.uuidString
    }
}
