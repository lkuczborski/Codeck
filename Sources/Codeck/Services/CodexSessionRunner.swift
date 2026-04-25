import Foundation

enum CodexSessionRunner {
  static func makeProcess(for block: CodexBlock, workingDirectory: URL?) -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

    var arguments = [
      "codex",
      "--ask-for-approval",
      "never",
      "exec",
      "--color",
      "never",
      "--skip-git-repo-check",
      "--sandbox",
      block.sandbox,
      "--ephemeral"
    ]

    if let model = block.model {
      arguments += ["--model", model]
    }

    if let profile = block.profile {
      arguments += ["--profile", profile]
    }

    arguments.append("-")

    process.arguments = arguments
    if let workingDirectory {
      process.currentDirectoryURL = workingDirectory
    }

    return process
  }
}
