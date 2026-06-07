import Foundation

func metadataValue(_ value: String) -> String {
  value
    .replacingOccurrences(of: "\r\n", with: " ")
    .replacingOccurrences(of: "\n", with: " ")
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

func fenceMarker(for body: String) -> String {
  let longestRun = body
    .split(whereSeparator: { $0 != "`" })
    .map(\.count)
    .max() ?? 0
  return String(repeating: "`", count: max(3, longestRun + 1))
}
