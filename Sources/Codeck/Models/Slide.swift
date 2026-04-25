import Foundation

struct Slide: Identifiable, Hashable {
  let id: UUID
  var markdown: String

  init(id: UUID = UUID(), markdown: String) {
    self.id = id
    self.markdown = markdown
  }

  var title: String {
    for line in markdown.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard trimmed.hasPrefix("#") else { continue }
      let title = trimmed.drop(while: { $0 == "#" || $0 == " " })
      if !title.isEmpty {
        return String(title)
      }
    }

    return "Untitled Slide"
  }

  var summary: String {
    for line in markdown.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }
      guard !trimmed.hasPrefix("#") else { continue }
      guard !trimmed.hasPrefix("```") else { continue }
      return trimmed
    }

    let blockCount = codexBlocks.count
    if blockCount == 1 {
      return "1 live Codex session"
    }

    if blockCount > 1 {
      return "\(blockCount) live Codex sessions"
    }

    return "Markdown slide"
  }

  var codexBlocks: [CodexBlock] {
    CodexBlock.extract(from: markdown)
  }
}
