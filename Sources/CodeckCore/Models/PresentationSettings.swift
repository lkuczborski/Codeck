import Foundation

public struct PresentationSettings: Hashable, Sendable {
  public var theme: PresentationTheme
  public var codex: DeckCodexSettings

  public static let `default` = PresentationSettings(
    theme: .studio,
    codex: .default
  )

  public init(theme: PresentationTheme, codex: DeckCodexSettings) {
    self.theme = theme
    self.codex = codex
  }
}

public struct DeckCodexSettings: Hashable, Sendable {
  public var model: String
  public var reasoning: CodexReasoningEffort
  public var sandbox: String

  public static let `default` = DeckCodexSettings(
    model: CodexModelOption.defaultModelID,
    reasoning: .medium,
    sandbox: "read-only"
  )

  public init(model: String, reasoning: CodexReasoningEffort, sandbox: String) {
    self.model = model
    self.reasoning = reasoning
    self.sandbox = sandbox
  }
}

public struct CodexModelOption: Identifiable, Hashable, Sendable {
  public var id: String
  public var displayName: String
  public var description: String
  public var supportedReasoningEfforts: [CodexReasoningEffort]
  public var defaultReasoningEffort: CodexReasoningEffort
  public var isDefault: Bool

  public init(
    id: String,
    displayName: String,
    description: String,
    supportedReasoningEfforts: [CodexReasoningEffort],
    defaultReasoningEffort: CodexReasoningEffort,
    isDefault: Bool
  ) {
    self.id = id
    self.displayName = displayName
    self.description = description
    self.supportedReasoningEfforts = supportedReasoningEfforts
    self.defaultReasoningEffort = defaultReasoningEffort
    self.isDefault = isDefault
  }

  public static let fallbackOptions: [CodexModelOption] = [
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

  public static var defaultOption: CodexModelOption {
    defaultOption(in: fallbackOptions)
  }

  public static var defaultModelID: String {
    defaultOption.id
  }

  public static func defaultOption(in options: [CodexModelOption]) -> CodexModelOption {
    options.first(where: \.isDefault) ?? options.first ?? fallbackOptions[0]
  }

  public static func option(for modelID: String, in options: [CodexModelOption] = fallbackOptions) -> CodexModelOption? {
    options.first { $0.id == modelID }
  }

  public static func normalizedModelID(_ value: String?) -> String {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return defaultModelID
    }

    return value
  }

  public static func normalizedReasoning(
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

public struct CodexReasoningEffort: RawRepresentable, CaseIterable, Identifiable, Hashable, Sendable {
  public var rawValue: String

  public static let low = CodexReasoningEffort(rawValue: "low")
  public static let medium = CodexReasoningEffort(rawValue: "medium")
  public static let high = CodexReasoningEffort(rawValue: "high")
  public static let xhigh = CodexReasoningEffort(rawValue: "xhigh")
  public static let allCases: [CodexReasoningEffort] = [.low, .medium, .high, .xhigh]

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public var id: String { rawValue }

  public var displayName: String {
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
