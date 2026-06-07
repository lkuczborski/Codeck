import CodeckCore
import Foundation

enum CodexSessionRunner {
  static func makeProcess(
    for block: CodexBlock,
    settings: DeckCodexSettings = .default,
    workingDirectory: URL?
  ) -> Process {
    let process = Process()
    let sessionDirectory = sessionWorkingDirectory(from: workingDirectory)
    var arguments = appServerArguments(for: block, settings: settings, workingDirectory: sessionDirectory)

    if let codexExecutable = codexExecutableURL() {
      process.executableURL = codexExecutable
    } else {
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      arguments.insert("codex", at: 0)
    }

    process.arguments = arguments
    process.currentDirectoryURL = sessionDirectory
    process.environment = environmentWithCodexSearchPath()

    return process
  }

  static func appServerArguments(
    for block: CodexBlock,
    settings: DeckCodexSettings = .default,
    workingDirectory sessionDirectory: URL
  ) -> [String] {
    var arguments: [String] = []
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
      sessionDirectory.path,
    ]

    arguments += [
      "app-server",
      "--listen",
      "stdio://",
    ]

    return arguments
  }

  static func sessionWorkingDirectory(from workingDirectory: URL?) -> URL {
    workingDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
  }

  static func environmentWithCodexSearchPath(
    _ environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> [String: String] {
    var environment = environment
    environment["PATH"] = augmentedPath(from: environment["PATH"])
    return environment
  }

  static func augmentedPath(from path: String?) -> String {
    let existingPaths = path?
      .split(separator: ":", omittingEmptySubsequences: true)
      .map(String.init) ?? []
    var paths: [String] = []

    for path in existingPaths + defaultCodexSearchPaths where !paths.contains(path) {
      paths.append(path)
    }

    return paths.joined(separator: ":")
  }

  static func codexExecutableURL(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManager = .default
  ) -> URL? {
    let override = environment["CODECK_CODEX_EXECUTABLE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let override, !override.isEmpty, fileManager.isExecutableFile(atPath: override) {
      return URL(fileURLWithPath: override)
    }

    for directory in augmentedPath(from: environment["PATH"]).split(separator: ":") {
      let candidate = URL(fileURLWithPath: String(directory), isDirectory: true)
        .appendingPathComponent("codex")
        .path
      if fileManager.isExecutableFile(atPath: candidate) {
        return URL(fileURLWithPath: candidate)
      }
    }

    return nil
  }

  private static let defaultCodexSearchPaths = [
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/Applications/Codex.app/Contents/Resources",
    "/usr/bin",
    "/bin",
    "/usr/sbin",
    "/sbin",
  ]
}
