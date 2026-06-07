import Foundation

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
