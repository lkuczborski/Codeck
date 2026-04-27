import XCTest
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

    XCTAssertEqual(arguments, ["codex", "app-server", "--listen", "stdio://"])
  }

  func testRunnerPassesProfileBeforeAppServerSubcommand() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      profile: "teaching",
      title: "Demo"
    )

    let arguments = CodexSessionRunner.makeProcess(for: block, workingDirectory: nil).arguments ?? []

    XCTAssertEqual(arguments, ["codex", "--profile", "teaching", "app-server", "--listen", "stdio://"])
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
  }
}
