import CodeckCore
import Foundation

struct LiveMutationResponse: Encodable {
    let document: OpenDocumentDescription
    let message: String
    let deck: LiveDeckDescription

    @MainActor
    init(document: LiveMCPDocumentSession, message: String, deck: PresentationDeck) {
        self.document = OpenDocumentDescription(document)
        self.message = message
        self.deck = LiveDeckDescription(deck)
    }
}
