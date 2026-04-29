import Foundation

enum MarkdownFence {
  static func openingMarker(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard let markerCharacter = trimmed.first, markerCharacter == "`" || markerCharacter == "~" else {
      return nil
    }

    let markerLength = trimmed.prefix(while: { $0 == markerCharacter }).count
    guard markerLength >= 3 else {
      return nil
    }

    return String(repeating: String(markerCharacter), count: markerLength)
  }

  static func infoString(in openingLine: String, marker: String) -> String {
    openingLine
      .trimmingCharacters(in: .whitespaces)
      .dropFirst(marker.count)
      .trimmingCharacters(in: .whitespaces)
  }

  static func isClosingLine(_ line: String, marker: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard let markerCharacter = marker.first, trimmed.first == markerCharacter else {
      return false
    }

    let markerLength = trimmed.prefix(while: { $0 == markerCharacter }).count
    guard markerLength >= marker.count else {
      return false
    }

    let trailingText = trimmed.dropFirst(markerLength)
    return trailingText.trimmingCharacters(in: .whitespaces).isEmpty
  }
}
