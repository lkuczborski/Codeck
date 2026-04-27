import Foundation

struct PresentationSettings: Hashable, Sendable {
  var theme: PresentationTheme
  var codex: DeckCodexSettings

  static let `default` = PresentationSettings(
    theme: .studio,
    codex: .default
  )
}

struct DeckCodexSettings: Hashable, Sendable {
  var model: String
  var reasoning: CodexReasoningEffort
  var sandbox: String

  static let `default` = DeckCodexSettings(
    model: CodexModelOption.defaultModelID,
    reasoning: .medium,
    sandbox: "read-only"
  )
}

struct CodexModelOption: Identifiable, Hashable, Sendable {
  var id: String
  var displayName: String
  var description: String
  var supportedReasoningEfforts: [CodexReasoningEffort]
  var defaultReasoningEffort: CodexReasoningEffort
  var isDefault: Bool

  static let fallbackOptions: [CodexModelOption] = [
    CodexModelOption(
      id: "gpt-5.5",
      displayName: "GPT-5.5",
      description: "Frontier model for complex coding, research, and real-world work.",
      supportedReasoningEfforts: CodexReasoningEffort.allCases,
      defaultReasoningEffort: .medium,
      isDefault: true
    ),
    CodexModelOption(
      id: "gpt-5.4",
      displayName: "gpt-5.4",
      description: "Strong model for everyday coding.",
      supportedReasoningEfforts: CodexReasoningEffort.allCases,
      defaultReasoningEffort: .medium,
      isDefault: false
    ),
    CodexModelOption(
      id: "gpt-5.4-mini",
      displayName: "GPT-5.4-Mini",
      description: "Small, fast, and cost-efficient model for simpler coding tasks.",
      supportedReasoningEfforts: CodexReasoningEffort.allCases,
      defaultReasoningEffort: .medium,
      isDefault: false
    ),
    CodexModelOption(
      id: "gpt-5.3-codex",
      displayName: "gpt-5.3-codex",
      description: "Coding-optimized model.",
      supportedReasoningEfforts: CodexReasoningEffort.allCases,
      defaultReasoningEffort: .medium,
      isDefault: false
    ),
    CodexModelOption(
      id: "gpt-5.3-codex-spark",
      displayName: "GPT-5.3-Codex-Spark",
      description: "Ultra-fast coding model.",
      supportedReasoningEfforts: CodexReasoningEffort.allCases,
      defaultReasoningEffort: .high,
      isDefault: false
    ),
    CodexModelOption(
      id: "gpt-5.2",
      displayName: "gpt-5.2",
      description: "Optimized for professional work and long-running agents.",
      supportedReasoningEfforts: CodexReasoningEffort.allCases,
      defaultReasoningEffort: .medium,
      isDefault: false
    )
  ]

  static var defaultOption: CodexModelOption {
    defaultOption(in: fallbackOptions)
  }

  static var defaultModelID: String {
    defaultOption.id
  }

  static func defaultOption(in options: [CodexModelOption]) -> CodexModelOption {
    options.first(where: \.isDefault) ?? options.first ?? fallbackOptions[0]
  }

  static func option(for modelID: String, in options: [CodexModelOption] = fallbackOptions) -> CodexModelOption? {
    options.first { $0.id == modelID }
  }

  static func normalizedModelID(_ value: String?) -> String {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return defaultModelID
    }

    return value
  }

  static func normalizedReasoning(
    _ reasoning: CodexReasoningEffort?,
    for modelID: String,
    in options: [CodexModelOption] = fallbackOptions
  ) -> CodexReasoningEffort {
    guard let option = option(for: modelID, in: options) else {
      return reasoning ?? .medium
    }

    if let reasoning, option.supportedReasoningEfforts.contains(reasoning) {
      return reasoning
    }

    if option.supportedReasoningEfforts.contains(.medium) {
      return .medium
    }

    return option.defaultReasoningEffort
  }
}

struct CodexReasoningEffort: RawRepresentable, CaseIterable, Identifiable, Hashable, Sendable {
  var rawValue: String

  static let low = CodexReasoningEffort(rawValue: "low")
  static let medium = CodexReasoningEffort(rawValue: "medium")
  static let high = CodexReasoningEffort(rawValue: "high")
  static let xhigh = CodexReasoningEffort(rawValue: "xhigh")
  static let allCases: [CodexReasoningEffort] = [.low, .medium, .high, .xhigh]

  var id: String { rawValue }

  var displayName: String {
    switch rawValue {
    case Self.low.rawValue:
      "Low"
    case Self.medium.rawValue:
      "Medium"
    case Self.high.rawValue:
      "High"
    case Self.xhigh.rawValue:
      "Extra High"
    default:
      rawValue
        .split(separator: "-")
        .map { $0.capitalized }
        .joined(separator: " ")
    }
  }
}
