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
    case .string(let value):
      value
    case .integer(let value):
      value
    }
  }
}

public struct JSONRPCMessageEnvelope: Decodable {
  public enum IDState: Equatable {
    case missing
    case invalid
    case valid(JSONRPCRequestID)
  }

  public let method: String?
  public let idState: IDState

  private enum CodingKeys: String, CodingKey {
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
    guard case .valid(let id) = idState else {
      return nil
    }
    return id
  }
}
