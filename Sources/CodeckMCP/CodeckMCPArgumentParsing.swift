import Foundation

func requiredString(_ arguments: [String: Any], _ key: String) throws -> String {
  guard let value = optionalString(arguments, key) else {
    throw CodeckMCPError.invalidParams("Missing required string argument '\(key)'.")
  }
  return value
}

func optionalString(_ arguments: [String: Any], _ key: String) -> String? {
  guard let value = arguments[key] as? String else { return nil }
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  return trimmed.isEmpty ? nil : value
}

func requiredInt(_ arguments: [String: Any], _ key: String) throws -> Int {
  guard let value = try optionalInt(arguments, key) else {
    throw CodeckMCPError.invalidParams("Missing required integer argument '\(key)'.")
  }
  return value
}

func optionalInt(_ arguments: [String: Any], _ key: String) throws -> Int? {
  guard let value = arguments[key] else { return nil }
  if let int = value as? Int {
    return int
  }
  if let number = value as? NSNumber {
    return number.intValue
  }
  throw CodeckMCPError.invalidParams("Argument '\(key)' must be an integer.")
}

func optionalBool(_ arguments: [String: Any], _ key: String) -> Bool? {
  if let bool = arguments[key] as? Bool {
    return bool
  }
  return (arguments[key] as? NSNumber)?.boolValue
}

func optionalStringArray(_ arguments: [String: Any], _ key: String) throws -> [String]? {
  guard let value = arguments[key] else { return nil }
  guard let strings = value as? [String] else {
    throw CodeckMCPError.invalidParams("Argument '\(key)' must be an array of strings.")
  }
  return strings
}

func validateCodexBlockID(_ value: String) throws {
  guard !value.contains(where: \.isWhitespace) else {
    throw CodeckMCPError.invalidParams("Codex block id must not contain whitespace.")
  }
}
