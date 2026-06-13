import CodeckCore
import Foundation

struct ValidationResponse: Encodable {
    let path: String
    let valid: Bool
    let warnings: [String]
    let deck: DeckDescription
}
