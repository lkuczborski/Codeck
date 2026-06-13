

public struct JSONRPCMessageEnvelope: Decodable {
    public enum IDState: Equatable {
        case missing
        case invalid
        case valid(JSONRPCRequestID)
    }

    public let method: String?
    public let idState: IDState

    enum CodingKeys: String, CodingKey {
        case id
        case method
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        method = try? container.decode(String.self, forKey: .method)

        if !container.contains(.id) {
            idState = .missing
        } else if (try? container.decodeNil(forKey: .id)) == true {
            idState = .invalid
        } else if let id = try? container.decode(JSONRPCRequestID.self, forKey: .id) {
            idState = .valid(id)
        } else {
            idState = .invalid
        }
    }

    public var responseID: JSONRPCRequestID? {
        guard case let .valid(id) = idState else {
            return nil
        }
        return id
    }
}
