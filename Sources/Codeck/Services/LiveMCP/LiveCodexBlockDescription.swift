import CodeckCore
import Foundation

struct LiveCodexBlockDescription: Encodable {
    let id: String
    let title: String
    let model: String?
    let reasoning: String?
    let sandbox: String?

    init(_ block: CodexBlock) {
        id = block.id
        title = block.title
        model = block.model
        reasoning = block.reasoning?.rawValue
        sandbox = block.sandbox
    }
}
