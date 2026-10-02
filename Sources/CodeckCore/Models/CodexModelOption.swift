import Foundation

public struct CodexModelOption: Identifiable, Hashable, Codable, Sendable {
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

    // A product default is configuration, not a maintained catalog of models.
    public static let defaultModelID = "gpt-6.1-sol"
    public static let defaultReasoningEffort = CodexReasoningEffort.low

    private static let preferredDefault = CodexModelOption(
        id: defaultModelID, displayName: defaultModelID, description: "",
        supportedReasoningEfforts: [defaultReasoningEffort],
        defaultReasoningEffort: defaultReasoningEffort, isDefault: true
    )

    public static func defaultOption(in options: [CodexModelOption]) -> CodexModelOption {
        options.first(where: { $0.id == defaultModelID }) ?? options.first(where: \.isDefault) ?? options.first ?? preferredDefault
    }

    public static func option(for modelID: String, in options: [CodexModelOption] = []) -> CodexModelOption? {
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
        in options: [CodexModelOption] = []
    ) -> CodexReasoningEffort {
        guard let option = option(for: modelID, in: options) else {
            return reasoning ?? (modelID == defaultModelID ? defaultReasoningEffort : .medium)
        }

        if let reasoning, option.supportedReasoningEfforts.contains(reasoning) {
            return reasoning
        }

        if reasoning == nil { return option.defaultReasoningEffort }

        if option.supportedReasoningEfforts.contains(.medium) {
            return .medium
        }

        return option.defaultReasoningEffort
    }
}
