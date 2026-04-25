import Foundation

enum YAMLFrontMatter {
  static func parse(from text: String) -> (values: [String: String], body: String)? {
    var lines = text.components(separatedBy: .newlines)
    while let first = lines.first, first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      lines.removeFirst()
    }

    guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
      return nil
    }

    lines.removeFirst()
    var headerLines: [String] = []

    while !lines.isEmpty {
      let line = lines.removeFirst()
      if line.trimmingCharacters(in: .whitespaces) == "---" {
        return (parseValues(from: headerLines), lines.joined(separator: "\n"))
      }
      headerLines.append(line)
    }

    return nil
  }

  private static func parseValues(from lines: [String]) -> [String: String] {
    var values: [String: String] = [:]
    var section: String?

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

      let isIndented = line.first?.isWhitespace == true
      if !isIndented, trimmed.hasSuffix(":") {
        section = String(trimmed.dropLast()).lowercased()
        continue
      }

      let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { continue }

      let key = parts[0].lowercased()
      let value = unquote(parts[1].trimmingCharacters(in: .whitespaces))
      if isIndented, let section {
        values["\(section).\(key)"] = value
      } else {
        values[key] = value
        section = nil
      }
    }

    return values
  }

  private static func unquote(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    if value.hasPrefix("\""), value.hasSuffix("\"") {
      return String(value.dropFirst().dropLast())
    }
    if value.hasPrefix("'"), value.hasSuffix("'") {
      return String(value.dropFirst().dropLast())
    }
    return value
  }
}
