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

    if let profile = block.profile ?? settings.profile {
      arguments += ["--profile", profile]
    }

    arguments += [
      "app-server",
      "--listen",
      "stdio://"
    ]

    process.arguments = arguments
    if let workingDirectory {
      process.currentDirectoryURL = workingDirectory
    }

    return process
  }
}
