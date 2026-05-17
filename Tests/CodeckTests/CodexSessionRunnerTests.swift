import XCTest
@testable import CodeckCore
@testable import Codeck

final class CodexSessionRunnerTests: XCTestCase {
  func testRunnerStartsCodexAppServerOverStdio() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      sandbox: "read-only",
      title: "Demo"
    )

    let arguments = CodexSessionRunner.makeProcess(for: block, workingDirectory: nil).arguments ?? []

    XCTAssertEqual(Array(arguments.prefix(5)), ["codex", "--sandbox", "read-only", "--ask-for-approval", "never"])
    XCTAssertEqual(arguments[5], "--cd")
    XCTAssertFalse(arguments[6].isEmpty)
    XCTAssertEqual(Array(arguments.suffix(3)), ["app-server", "--listen", "stdio://"])
  }

  func testRunnerPassesProfileBeforeAppServerSubcommand() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      profile: "teaching",
      title: "Demo"
    )

    let arguments = CodexSessionRunner.makeProcess(for: block, workingDirectory: nil).arguments ?? []

    XCTAssertEqual(Array(arguments[0...2]), ["codex", "--profile", "teaching"])
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
    XCTAssertEqual(process.arguments?[6], url.path)
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

    let arguments = CodexSessionRunner.makeProcess(for: block, workingDirectory: nil).arguments ?? []

    XCTAssertEqual(arguments[2], "read-only")
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

    let arguments = CodexSessionRunner.makeProcess(for: block, settings: settings, workingDirectory: nil).arguments ?? []

    XCTAssertEqual(arguments[2], "workspace-write")
  }

  func testReadOnlyTurnPolicyDisablesNetwork() {
    let policy = CodexSandbox.turnPolicy(
      for: "read-only",
      workingDirectory: URL(fileURLWithPath: "/tmp/deck", isDirectory: true)
    )

    XCTAssertEqual(policy["type"] as? String, "readOnly")
    XCTAssertEqual(policy["networkAccess"] as? Bool, false)
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

  func testDangerFullAccessTurnPolicyRequiresExplicitDangerMode() {
    let policy = CodexSandbox.turnPolicy(
      for: "danger-full-access",
      workingDirectory: URL(fileURLWithPath: "/tmp/deck", isDirectory: true)
    )

    XCTAssertEqual(policy["type"] as? String, "dangerFullAccess")
  }
}
