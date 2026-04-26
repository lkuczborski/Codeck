import Foundation

enum CodexSessionOutputFormatter {
  static func markdown(from output: CodexSessionOutput?, verbose: Bool) -> String {
    guard let output else { return "Ready to run." }

    let rawText = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rawText.isEmpty else {
      return output.state == .running ? "Waiting for Codex response..." : "Ready to run."
    }

    if verbose {
      return rawText
    }

    let finalResponse = normalizedText(output.standardOutput)
    if !finalResponse.isEmpty {
      return finalResponse
    }

    if let response = responseText(from: output.standardError) ?? responseText(from: rawText) {
      return response
    }

    return output.state == .running ? "Waiting for Codex response..." : rawText
  }

  static func responseText(from text: String) -> String? {
    let normalized = normalizedText(text)
    let lines = normalized.components(separatedBy: "\n")

    guard let markerIndex = lines.lastIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "codex" }) else {
      return nil
    }

    let response = removeUsageFooter(from: lines.dropFirst(markerIndex + 1)
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines))

    return response.isEmpty ? nil : response
  }

  private static func normalizedText(_ text: String) -> String {
    stripANSIEscapes(from: text)
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func removeUsageFooter(from text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"(?i)\s*tokens used\s+[0-9,]+"#) else {
      return text
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          let matchRange = Range(match.range, in: text) else {
      return text
    }

    let response = text[..<matchRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
    return response.isEmpty ? text : String(response)
  }

  private static func stripANSIEscapes(from text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]") else {
      return text
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
  }
}
