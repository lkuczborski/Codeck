public enum JSONRPCRequestID: Decodable, Equatable {
    case string(String)
    case integer(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }

        if let integer = try? container.decode(Int.self) {
            self = .integer(integer)
            return
        }

        throw DecodingError.typeMismatch(
            JSONRPCRequestID.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Request id must be a string or integer.")
        )
    }

    public var jsonValue: Any {
        switch self {
        case let .string(value):
            value
        case let .integer(value):
            value
        }
    }
}
