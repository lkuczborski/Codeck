import CodeckCore
import Foundation

struct LiveValidationResponse: Encodable {
  let document: OpenDocumentDescription
  let valid: Bool
  let warnings: [String]
  let deck: LiveDeckDescription

  @MainActor
  init(document: LiveMCPDocumentSession, valid: Bool, warnings: [String], deck: PresentationDeck) {
    self.document = OpenDocumentDescription(document)
    self.valid = valid
    self.warnings = warnings
    self.deck = LiveDeckDescription(deck)
  }
}
