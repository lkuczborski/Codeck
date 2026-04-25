import XCTest
@testable import Codeck

final class CodexSessionRunnerTests: XCTestCase {
  func testApprovalPolicyIsPassedBeforeExecSubcommand() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      sandbox: "read-only",
      title: "Demo"
    )

    let arguments = CodexSessionRunner.makeProcess(for: block, workingDirectory: nil).arguments ?? []

    XCTAssertEqual(Array(arguments.prefix(4)), ["codex", "--ask-for-approval", "never", "exec"])
    XCTAssertFalse(Array(arguments.dropFirst(4)).contains("--ask-for-approval"))
  }
}
