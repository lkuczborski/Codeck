@testable import Codeck
@testable import CodeckCore
import XCTest

final class CodexSessionRunnerTests: XCTestCase {
  func testRunnerStartsCodexAppServerOverStdio() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      sandbox: "read-only",
      title: "Demo"
    )
    let workingDirectory = CodexSessionRunner.sessionWorkingDirectory(from: nil)

    let arguments = CodexSessionRunner.appServerArguments(for: block, workingDirectory: workingDirectory)

    XCTAssertEqual(Array(arguments.prefix(4)), ["--sandbox", "read-only", "--ask-for-approval", "never"])
    XCTAssertEqual(arguments[4], "--cd")
    XCTAssertFalse(arguments[5].isEmpty)
    XCTAssertEqual(Array(arguments.suffix(3)), ["app-server", "--listen", "stdio://"])
  }

  func testRunnerPassesProfileBeforeAppServerSubcommand() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      profile: "teaching",
      title: "Demo"
    )
    let workingDirectory = CodexSessionRunner.sessionWorkingDirectory(from: nil)

    let arguments = CodexSessionRunner.appServerArguments(for: block, workingDirectory: workingDirectory)

    XCTAssertEqual(Array(arguments[0 ... 1]), ["--profile", "teaching"])
    XCTAssertEqual(Array(arguments.suffix(3)), ["app-server", "--listen", "stdio://"])
  }

  func testRunnerUsesRequestedWorkingDirectory() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      title: "Demo"
    )
    let url = URL(fileURLWithPath: "/tmp")

    let process = CodexSessionRunner.makeProcess(for: block, workingDirectory: url)

    XCTAssertEqual(process.currentDirectoryURL?.path, url.path)
    XCTAssertEqual(argument(after: "--cd", in: process.arguments ?? []), url.path)
  }

  func testRunnerAddsCommonCodexInstallLocationsToPATH() {
    let path = CodexSessionRunner.augmentedPath(from: "/usr/bin:/bin")

    XCTAssertTrue(path.contains("/opt/homebrew/bin"))
    XCTAssertTrue(path.contains("/usr/local/bin"))
    XCTAssertTrue(path.contains("/Applications/Codex.app/Contents/Resources"))
  }

  func testRunnerUsesExecutableOverrideWhenAvailable() {
    let environment = ["CODECK_CODEX_EXECUTABLE": "/bin/sh", "PATH": "/usr/bin:/bin"]

    let executable = CodexSessionRunner.codexExecutableURL(environment: environment)

    XCTAssertEqual(executable?.path, "/bin/sh")
  }

  func testRunnerUsesTemporaryWorkingDirectoryWhenDeckIsUnsaved() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      title: "Demo"
    )

    let process = CodexSessionRunner.makeProcess(for: block, workingDirectory: nil)

    XCTAssertEqual(process.currentDirectoryURL?.path, CodexSessionRunner.sessionWorkingDirectory(from: nil).path)
  }

  func testRunnerNormalizesUnknownSandboxToReadOnly() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      sandbox: "surprise-me",
      title: "Demo"
    )
    let workingDirectory = CodexSessionRunner.sessionWorkingDirectory(from: nil)

    let arguments = CodexSessionRunner.appServerArguments(for: block, workingDirectory: workingDirectory)

    XCTAssertEqual(argument(after: "--sandbox", in: arguments), "read-only")
  }

  func testRunnerUsesBlockSandboxOverride() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      sandbox: "workspace-write",
      title: "Demo"
    )
    let settings = DeckCodexSettings(
      model: "gpt-5.5",
      reasoning: .medium,
      sandbox: "read-only"
    )

    let workingDirectory = CodexSessionRunner.sessionWorkingDirectory(from: nil)
    let arguments = CodexSessionRunner.appServerArguments(for: block, settings: settings, workingDirectory: workingDirectory)

    XCTAssertEqual(argument(after: "--sandbox", in: arguments), "workspace-write")
  }

  func testReadOnlyTurnPolicyDisablesNetwork() {
    let policy = CodexSandbox.turnPolicy(
      for: "read-only",
      workingDirectory: URL(fileURLWithPath: "/tmp/deck", isDirectory: true)
    )

    XCTAssertEqual(policy["type"] as? String, "readOnly")
    XCTAssertEqual(policy["networkAccess"] as? Bool, false)
  }

  func testReadOnlyTurnPolicyCanOptIntoNetwork() {
    let policy = CodexSandbox.turnPolicy(
      for: "read-only",
      workingDirectory: URL(fileURLWithPath: "/tmp/deck", isDirectory: true),
      allowsNetwork: true
    )

    XCTAssertEqual(policy["type"] as? String, "readOnly")
    XCTAssertEqual(policy["networkAccess"] as? Bool, true)
  }

  func testWorkspaceWriteTurnPolicyOnlyWritesWorkingDirectory() {
    let workingDirectory = URL(fileURLWithPath: "/tmp/deck", isDirectory: true)

    let policy = CodexSandbox.turnPolicy(for: "workspace-write", workingDirectory: workingDirectory)

    XCTAssertEqual(policy["type"] as? String, "workspaceWrite")
    XCTAssertEqual(policy["writableRoots"] as? [String], [workingDirectory.path])
    XCTAssertEqual(policy["networkAccess"] as? Bool, false)
    XCTAssertEqual(policy["excludeTmpdirEnvVar"] as? Bool, false)
    XCTAssertEqual(policy["excludeSlashTmp"] as? Bool, false)
  }

  func testWorkspaceWriteTurnPolicyCanOptIntoNetwork() {
    let workingDirectory = URL(fileURLWithPath: "/tmp/deck", isDirectory: true)

    let policy = CodexSandbox.turnPolicy(
      for: "workspace-write",
      workingDirectory: workingDirectory,
      allowsNetwork: true
    )

    XCTAssertEqual(policy["type"] as? String, "workspaceWrite")
    XCTAssertEqual(policy["writableRoots"] as? [String], [workingDirectory.path])
    XCTAssertEqual(policy["networkAccess"] as? Bool, true)
  }

  func testDangerFullAccessTurnPolicyRequiresExplicitDangerMode() {
    let policy = CodexSandbox.turnPolicy(
      for: "danger-full-access",
      workingDirectory: URL(fileURLWithPath: "/tmp/deck", isDirectory: true)
    )

    XCTAssertEqual(policy["type"] as? String, "dangerFullAccess")
  }

  private func argument(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag) else { return nil }
    let valueIndex = arguments.index(after: index)
    guard valueIndex < arguments.endIndex else { return nil }
    return arguments[valueIndex]
  }
}
