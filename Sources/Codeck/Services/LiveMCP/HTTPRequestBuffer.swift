import Foundation
import Network

final class HTTPRequestBuffer: @unchecked Sendable {
    private var data = Data()

    var request: HTTPRequest? {
        HTTPRequest(data: data)
    }

    func append(_ newData: Data) {
        data.append(newData)
    }
}
