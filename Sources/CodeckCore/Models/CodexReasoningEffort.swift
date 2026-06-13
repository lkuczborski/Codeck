import Foundation

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

    public var id: String {
        rawValue
    }

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
                .map(\.capitalized)
                .joined(separator: " ")
        }
    }
}
