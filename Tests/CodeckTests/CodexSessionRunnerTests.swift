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

  func testDeckSettingsProvideCodexDefaults() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      title: "Demo"
    )
    let settings = DeckCodexSettings(
      model: "gpt-5.2",
      reasoning: .high,
      profile: "teaching",
      sandbox: "workspace-write"
    )

    let arguments = CodexSessionRunner.makeProcess(for: block, settings: settings, workingDirectory: nil).arguments ?? []

    XCTAssertTrue(arguments.contains("--model"))
    XCTAssertTrue(arguments.contains("gpt-5.2"))
    XCTAssertTrue(arguments.contains("model_reasoning_effort=\"high\""))
    XCTAssertTrue(arguments.contains("--profile"))
    XCTAssertTrue(arguments.contains("teaching"))
    XCTAssertEqual(value(after: "--sandbox", in: arguments), "workspace-write")
  }

  func testCodexBlockOverridesDeckDefaults() {
    let block = CodexBlock(
      id: "demo",
      prompt: "Explain this.",
      model: "gpt-5.4",
      reasoning: .xhigh,
      sandbox: "danger-full-access",
      title: "Demo"
    )
    let settings = DeckCodexSettings(
      model: "gpt-5.2",
      reasoning: .low,
      profile: nil,
      sandbox: "read-only"
    )

    let arguments = CodexSessionRunner.makeProcess(for: block, settings: settings, workingDirectory: nil).arguments ?? []

    XCTAssertEqual(value(after: "--model", in: arguments), "gpt-5.4")
    XCTAssertTrue(arguments.contains("model_reasoning_effort=\"xhigh\""))
    XCTAssertEqual(value(after: "--sandbox", in: arguments), "danger-full-access")
  }

  private func value(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
      return nil
    }
    return arguments[index + 1]
  }
}
