import CodeckCore
import Foundation

struct MutationResponse: Encodable {
  let path: String
  let message: String
  let deck: DeckDescription
}
