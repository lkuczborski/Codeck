import Foundation

struct PresentationSettings: Hashable {
  var theme: PresentationTheme
  var codex: DeckCodexSettings

  static let `default` = PresentationSettings(
    theme: .studio,
    codex: .default
  )
}

struct DeckCodexSettings: Hashable {
  var model: String?
  var reasoning: CodexReasoningEffort?
  var profile: String?
  var sandbox: String

  static let `default` = DeckCodexSettings(
    model: nil,
    reasoning: nil,
    profile: nil,
    sandbox: "read-only"
  )
}

enum CodexReasoningEffort: String, CaseIterable, Identifiable {
  case low
  case medium
  case high
  case xhigh

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .low:
      "Low"
    case .medium:
      "Medium"
    case .high:
      "High"
    case .xhigh:
      "Extra High"
    }
  }
}
