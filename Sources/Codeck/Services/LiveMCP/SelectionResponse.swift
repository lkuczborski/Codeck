import CodeckCore
import Foundation

struct SelectionResponse: Encodable {
  let document: OpenDocumentDescription
  let selectedSlideIndex: Int?

  @MainActor
  init(document: LiveMCPDocumentSession) {
    self.document = OpenDocumentDescription(document)
    selectedSlideIndex = document.selectedSlideIndex()
  }
}
