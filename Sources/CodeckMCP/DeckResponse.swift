import CodeckCore
import Foundation

struct DeckResponse: Encodable {
    let path: String
    let deck: DeckDescription
    let markdown: String?
}
