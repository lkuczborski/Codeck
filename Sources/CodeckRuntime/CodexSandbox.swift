import CodeckCore
import Foundation

public enum CodexSandbox {
    public static let supportedModes = Set(["read-only", "workspace-write", "danger-full-access"])

    public static func mode(for block: CodexBlock, settings: DeckCodexSettings) -> String {
        normalizedMode(block.sandbox ?? settings.sandbox)
    }

    public static func normalizedMode(_ value: String) -> String {
        let mode = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return supportedModes.contains(mode) ? mode : "read-only"
    }

    public static func turnPolicy(
        for mode: String,
        workingDirectory: URL,
        allowsNetwork: Bool = false
    ) -> [String: Any] {
        switch normalizedMode(mode) {
        case "workspace-write":
            [
                "type": "workspaceWrite",
                "writableRoots": [workingDirectory.path],
                "networkAccess": allowsNetwork,
                "excludeTmpdirEnvVar": false,
                "excludeSlashTmp": false,
            ]
        case "danger-full-access":
            [
                "type": "dangerFullAccess",
            ]
        default:
            [
                "type": "readOnly",
                "networkAccess": allowsNetwork,
            ]
        }
    }
}
