import Foundation

enum CodexSessionOutputFormatter {
  static func markdown(from output: CodexSessionOutput?, verbose: Bool) -> String {
    guard let output else { return "Ready to run." }

    let cleanOutput = normalizedText(output.standardOutput)
    let rawText = output.text.trimmingCharacters(in: .whitespacesAndNewlines)

    if verbose {
      if !rawText.isEmpty {
        return rawText
      }

      if !cleanOutput.isEmpty {
        return cleanOutput
      }

      return output.state == .running ? "Thinking..." : "Ready to run."
    }

    if !cleanOutput.isEmpty {
      return cleanOutput
    }

    guard !rawText.isEmpty else {
      return output.state == .running ? "Thinking..." : "Ready to run."
    }

    if output.state == .running,
       let response = responseText(from: output.standardError) ?? responseText(from: rawText) {
      return response
    }

    if let response = responseText(from: output.standardError) ?? responseText(from: rawText) {
      return response
    }

    return output.state == .running ? "Thinking..." : rawText
  }

  static func responseText(from text: String) -> String? {
    let normalized = normalizedText(text)
    let lines = normalized.components(separatedBy: "\n")

    guard let marker = responseMarker(in: lines) else {
      return nil
    }

    var responseLines = Array(lines.dropFirst(marker.index + 1))
    if !marker.inlineText.isEmpty {
      responseLines.insert(marker.inlineText, at: 0)
    }

    let response = removeUsageFooter(from: responseLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))

    return response.isEmpty ? nil : response
  }

  private static func responseMarker(in lines: [String]) -> (index: Int, inlineText: String)? {
    for index in lines.indices.reversed() {
      let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed == "codex" {
        return (index, "")
      }

      guard trimmed.hasPrefix("codex ") else { continue }
      let inlineText = String(trimmed.dropFirst("codex ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
      return (index, inlineText)
    }

    return nil
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
