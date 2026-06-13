import CodeckCore
import Foundation

struct LiveSlideDescription: Encodable {
    let index: Int
    let title: String
    let summary: String
    let codexBlockCount: Int
    let codexBlocks: [LiveCodexBlockDescription]
    let markdown: String?

    init(index: Int, slide: Slide, includeMarkdown: Bool) {
        self.index = index
        title = slide.title
        summary = slide.summary
        codexBlockCount = slide.codexBlocks.count
        codexBlocks = slide.codexBlocks.map(LiveCodexBlockDescription.init)
        markdown = includeMarkdown ? slide.markdown : nil
    }
}
