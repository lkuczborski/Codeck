import CodeckCore
import Foundation

struct LiveSlideResponse: Encodable {
    let document: OpenDocumentDescription
    let index: Int
    let slide: LiveSlideDescription

    @MainActor
    init(document: LiveMCPDocumentSession, index: Int, slide: Slide) {
        self.document = OpenDocumentDescription(document)
        self.index = index
        self.slide = LiveSlideDescription(index: index, slide: slide, includeMarkdown: true)
    }
}
