import Foundation

public enum CodexSessionState: String, Hashable, Sendable {
    case idle
    case running
    case completed
    case failed
    case stopped
}
