import Foundation

public struct CodexSessionOutput: Hashable, Sendable {
    public var state: CodexSessionState
    public var text: String
    public var standardOutput: String
    public var standardError: String

    public init(
        state: CodexSessionState,
        text: String,
        standardOutput: String = "",
        standardError: String = ""
    ) {
        self.state = state
        self.text = text
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}
