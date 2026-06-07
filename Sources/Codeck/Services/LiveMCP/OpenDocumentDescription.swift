import CodeckCore
import Foundation

struct OpenDocumentDescription: Encodable {
  let documentID: String
  let name: String
  let path: String?
  let selectedSlideIndex: Int?
  let slideCount: Int

  @MainActor
  init(_ document: LiveMCPDocumentSession) {
    documentID = document.id.uuidString
    name = document.displayName
    path = document.fileURL()?.path
    selectedSlideIndex = document.selectedSlideIndex()
    slideCount = document.deck().slides.count
  }
}
