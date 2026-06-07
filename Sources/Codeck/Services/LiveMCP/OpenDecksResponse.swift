import CodeckCore
import Foundation

struct OpenDecksResponse: Encodable {
  let documents: [OpenDocumentDescription]
}
