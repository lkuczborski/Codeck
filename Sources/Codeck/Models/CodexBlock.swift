import Foundation

struct CodexBlock: Identifiable, Hashable {
  var id: String
  var prompt: String
  var model: String?
  var reasoning: CodexReasoningEffort?
  var profile: String?
  var sandbox: String?
  var title: String

  init(
    id: String,
    prompt: String,
    model: String? = nil,
    reasoning: CodexReasoningEffort? = nil,
    profile: String? = nil,
    sandbox: String? = nil,
    title: String
  ) {
    self.id = id
    self.prompt = prompt
    self.model = model
    self.reasoning = reasoning
    self.profile = profile
    self.sandbox = sandbox
    self.title = title
  }

  static func extract(from markdown: String) -> [CodexBlock] {
    let lines = markdown.components(separatedBy: .newlines)
    var blocks: [CodexBlock] = []
    var index = 0

    while index < lines.count {
      let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
      guard let fence = MarkdownFence.openingMarker(in: trimmed) else {
        index += 1
        continue
      }

      let opening = MarkdownFence.infoString(in: trimmed, marker: fence)
      guard opening.hasPrefix("codex") else {
        index += 1
        continue
      }

      var body: [String] = []
      index += 1

      while index < lines.count {
        if MarkdownFence.isClosingLine(lines[index], marker: fence) {
          break
        }
        body.append(lines[index])
        index += 1
      }

      if let block = parse(opening: opening, body: body.joined(separator: "\n")) {
        blocks.append(block)
      }

      index += 1
    }

    return blocks
  }

  private static func parse(opening: String, body: String) -> CodexBlock? {
    var attributes = parseAttributes(from: opening)
    let parsedBody = parseFrontMatter(from: body)
    attributes.merge(parsedBody.attributes) { current, _ in current }

    let prompt = parsedBody.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !prompt.isEmpty else { return nil }

    let id = attributes["id"] ?? stableID(for: prompt + (attributes["model"] ?? ""))
    let title = attributes["title"] ?? "Codex Session"

    return CodexBlock(
      id: id,
      prompt: prompt,
      model: emptyToNil(attributes["model"]),
      reasoning: reasoning(from: attributes),
      profile: emptyToNil(attributes["profile"]),
      sandbox: emptyToNil(attributes["sandbox"]),
      title: title
    )
  }

  private static func reasoning(from attributes: [String: String]) -> CodexReasoningEffort? {
    let value = emptyToNil(attributes["reasoning"] ?? attributes["reasoning_effort"])
    return value.map(CodexReasoningEffort.init(rawValue:))
  }

  private static func parseAttributes(from opening: String) -> [String: String] {
    let raw = opening.replacingOccurrences(of: "codex", with: "").trimmingCharacters(in: .whitespaces)
    guard !raw.isEmpty else { return [:] }

    var attributes: [String: String] = [:]
    for token in raw.components(separatedBy: .whitespaces) where token.contains("=") {
      let parts = token.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { continue }
      attributes[parts[0].lowercased()] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
    return attributes
  }

  private static func parseFrontMatter(from body: String) -> (attributes: [String: String], prompt: String) {
    var attributes: [String: String] = [:]
    var promptLines = body.components(separatedBy: .newlines)
    var metadataLineCount = 0

    for line in promptLines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        metadataLineCount += 1
        break
      }

      let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
      guard parts.count == 2 else {
        metadataLineCount = 0
        attributes.removeAll()
        break
      }

      attributes[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
      metadataLineCount += 1
    }

    if metadataLineCount > 0 {
      promptLines.removeFirst(min(metadataLineCount, promptLines.count))
    }

    return (attributes, promptLines.joined(separator: "\n"))
  }

  private static func emptyToNil(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }
    return value
  }

  private static func stableID(for seed: String) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in seed.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 0x100000001b3
    }
    return String(format: "codex-%016llx", hash)
  }
}
