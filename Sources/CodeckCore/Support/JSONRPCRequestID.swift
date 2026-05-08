import Foundation

public enum JSONRPCRequestID {
  case string(String)
  case integer(Int)

  public init?(_ rawValue: Any?) {
    guard let rawValue, !(rawValue is NSNull) else {
      return nil
    }

    if let string = rawValue as? String {
      self = .string(string)
      return
    }

    guard let number = rawValue as? NSNumber,
          CFGetTypeID(number) != CFBooleanGetTypeID() else {
      return nil
    }

    let value = number.doubleValue
    guard value.isFinite,
          value.rounded(.towardZero) == value,
          value >= Double(Int.min),
          value <= Double(Int.max) else {
      return nil
    }
    self = .integer(number.intValue)
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
