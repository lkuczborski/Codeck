import CodeckCore
import Foundation

struct LiveDeckResponse: Encodable {
  let document: OpenDocumentDescription
  let deck: LiveDeckDescription
  let markdown: String?

  @MainActor
  init(document: LiveMCPDocumentSession, deck: PresentationDeck, markdown: String?) {
    self.document = OpenDocumentDescription(document)
    self.deck = LiveDeckDescription(deck)
    self.markdown = markdown
  }
}
