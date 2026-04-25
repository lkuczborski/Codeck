import Foundation

enum CodexSessionRunner {
  static func makeProcess(
    for block: CodexBlock,
    settings: DeckCodexSettings = .default,
    workingDirectory: URL?
  ) -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    let resolvedSandbox = block.sandbox ?? settings.sandbox

    var arguments = [
      "codex",
      "--ask-for-approval",
      "never",
      "exec",
      "--color",
      "never",
      "--skip-git-repo-check",
      "--sandbox",
      resolvedSandbox,
      "--ephemeral"
    ]

    if let model = block.model ?? settings.model {
      arguments += ["--model", model]
    }

    if let reasoning = block.reasoning ?? settings.reasoning {
      arguments += ["-c", "model_reasoning_effort=\"\(reasoning.rawValue)\""]
    }

    if let profile = block.profile ?? settings.profile {
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
