import CodeckCore
import Foundation

enum CodexSessionRunner {
  static func makeProcess(
    for block: CodexBlock,
    settings: DeckCodexSettings = .default,
    workingDirectory: URL?
  ) -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    var arguments = ["codex"]
    let sessionDirectory = sessionWorkingDirectory(from: workingDirectory)
    let sandboxMode = CodexSandbox.mode(for: block, settings: settings)

    if let profile = block.profile {
      arguments += ["--profile", profile]
    }

    arguments += [
      "--sandbox",
      sandboxMode,
      "--ask-for-approval",
      "never",
      "--cd",
      sessionDirectory.path
    ]

    arguments += [
      "app-server",
      "--listen",
      "stdio://"
    ]

    process.arguments = arguments
    process.currentDirectoryURL = sessionDirectory

    return process
  }

  static func sessionWorkingDirectory(from workingDirectory: URL?) -> URL {
    workingDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
  }
}

enum CodexSandbox {
  private static let supportedModes = Set(["read-only", "workspace-write", "danger-full-access"])

  static func mode(for block: CodexBlock, settings: DeckCodexSettings) -> String {
    normalizedMode(block.sandbox ?? settings.sandbox)
  }

  static func normalizedMode(_ value: String) -> String {
    let mode = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return supportedModes.contains(mode) ? mode : "read-only"
  }

  static func turnPolicy(
    for mode: String,
    workingDirectory: URL,
    allowsNetwork: Bool = false
  ) -> [String: Any] {
    switch normalizedMode(mode) {
    case "workspace-write":
      return [
        "type": "workspaceWrite",
        "writableRoots": [workingDirectory.path],
        "networkAccess": allowsNetwork,
        "excludeTmpdirEnvVar": false,
        "excludeSlashTmp": false
      ]
    case "danger-full-access":
      return [
        "type": "dangerFullAccess"
      ]
    default:
      return [
        "type": "readOnly",
        "networkAccess": allowsNetwork
      ]
    }
  }
}
