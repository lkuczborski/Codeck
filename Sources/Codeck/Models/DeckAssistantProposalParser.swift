import CodeckCore
import Foundation

enum DeckAssistantProposalParser {
  static func proposal(from text: String, deck: PresentationDeck) throws -> DeckAssistantProposal {
    let json = try extractJSONObject(from: text)
    let data = Data(json.utf8)
    let payload: DeckAssistantProposalPayload

    do {
      payload = try JSONDecoder().decode(DeckAssistantProposalPayload.self, from: data)
    } catch {
      throw DeckAssistantProposalParseError.invalidJSON(error.localizedDescription)
    }

    let changes = payload.changes.enumerated().compactMap { offset, payloadChange in
      change(from: payloadChange, offset: offset, deck: deck)
    }

    guard !changes.isEmpty else {
      throw DeckAssistantProposalParseError.noValidChanges
    }

    return DeckAssistantProposal(
      title: nonEmpty(payload.title) ?? "Codex proposal",
      summary: nonEmpty(payload.summary) ?? "\(changes.count) proposed change\(changes.count == 1 ? "" : "s").",
      changes: changes
    )
  }

  private static func change(
    from payload: DeckAssistantChangePayload,
    offset: Int,
    deck: PresentationDeck
  ) -> DeckAssistantChange? {
    let afterMarkdown = payload.afterMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !afterMarkdown.isEmpty else { return nil }

    let operationName = payload.operation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let operation: DeckAssistantChangeOperation
    let beforeMarkdown: String?

    switch operationName {
    case "replace":
      guard let index = normalizedSlideIndex(payload.slideIndex, in: deck) else {
        return nil
      }
      operation = .replace(index: index)
      beforeMarkdown = deck.slides[index].markdown
    case "insert":
      operation = .insert(position: normalizedInsertPosition(payload.insertPosition ?? payload.slideIndex, in: deck))
      beforeMarkdown = nil
    default:
      return nil
    }

    return DeckAssistantChange(
      id: stableID(payload.id, fallback: "assistant-change-\(offset)"),
      title: nonEmpty(payload.title) ?? defaultTitle(for: operation),
      detail: nonEmpty(payload.detail) ?? "Codex proposed this change from the deck context.",
      operation: operation,
      beforeMarkdown: beforeMarkdown,
      afterMarkdown: afterMarkdown
    )
  }

  private static func normalizedSlideIndex(_ value: Int?, in deck: PresentationDeck) -> Int? {
    guard let value else { return nil }
    if deck.slides.indices.contains(value) {
      return value
    }

    let oneBased = value - 1
    if deck.slides.indices.contains(oneBased) {
      return oneBased
    }

    return nil
  }

  private static func normalizedInsertPosition(_ value: Int?, in deck: PresentationDeck) -> Int {
    guard let value else { return deck.slides.count }
    if (0 ... deck.slides.count).contains(value) {
      return value
    }

    let oneBased = value - 1
    if (0 ... deck.slides.count).contains(oneBased) {
      return oneBased
    }

    return min(max(value, 0), deck.slides.count)
  }

  private static func defaultTitle(for operation: DeckAssistantChangeOperation) -> String {
    switch operation {
    case .insert:
      "Insert slide"
    case let .replace(index):
      "Rewrite slide \(index + 1)"
    }
  }

  private static func stableID(_ value: String?, fallback: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let filtered = String(trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    let collapsed = filtered
      .split(separator: "-")
      .joined(separator: "-")
      .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
    return collapsed.isEmpty ? fallback : collapsed
  }

  private static func extractJSONObject(from text: String) throws -> String {
    if let fencedJSON = extractFencedJSON(from: text) {
      return fencedJSON
    }

    if let object = extractBalancedJSONObject(from: text) {
      return object
    }

    throw DeckAssistantProposalParseError.missingJSONObject
  }

  private static func extractFencedJSON(from text: String) -> String? {
    for marker in ["```json", "```JSON", "```"] {
      guard let start = text.range(of: marker) else { continue }
      let remainder = text[start.upperBound...]
      guard let end = remainder.range(of: "```") else { continue }
      let candidate = String(remainder[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
      if candidate.first == "{" {
        return candidate
      }
    }

    return nil
  }

  private static func extractBalancedJSONObject(from text: String) -> String? {
    var startIndex: String.Index?
    var depth = 0
    var isInsideString = false
    var isEscaped = false

    for index in text.indices {
      let character = text[index]

      if startIndex == nil {
        guard character == "{" else { continue }
        startIndex = index
        depth = 1
        continue
      }

      if isInsideString {
        if isEscaped {
          isEscaped = false
        } else if character == "\\" {
          isEscaped = true
        } else if character == "\"" {
          isInsideString = false
        }
        continue
      }

      if character == "\"" {
        isInsideString = true
      } else if character == "{" {
        depth += 1
      } else if character == "}" {
        depth -= 1
        if depth == 0, let startIndex {
          return String(text[startIndex ... index])
        }
      }
    }

    return nil
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }
}
