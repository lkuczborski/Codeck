import CodeckCore
import Foundation

struct SlideResponse: Encodable {
    let path: String
    let index: Int
    let slide: SlideDescription

    init(path: String, index: Int, slide: Slide) {
        self.path = path
        self.index = index
        self.slide = SlideDescription(index: index, slide: slide, includeMarkdown: true)
    }
}
