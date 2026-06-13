@testable import Codeck
import XCTest

final class CodexSessionOutputFormatterTests: XCTestCase {
    func testMarkdownDefaultsToReadyOrThinkingBasedOnState() {
        XCTAssertEqual(CodexSessionOutputFormatter.markdown(from: nil), "Ready to run.")
        XCTAssertEqual(CodexSessionOutputFormatter.markdown(from: CodexSessionOutput(state: .idle, text: "")), "Ready to run.")
        XCTAssertEqual(CodexSessionOutputFormatter.markdown(from: CodexSessionOutput(state: .running, text: "")), "Thinking...")
    }

    func testMarkdownStripsAnsiEscapesAndUsageFooterFromTranscriptResponse() {
        let output = CodexSessionOutput(
            state: .completed,
            text:
            """
            \u{001B}[32mcodex\u{001B}[0m
            Final answer.

            tokens used 1,234
            """
        )

        XCTAssertEqual(CodexSessionOutputFormatter.markdown(from: output), "Final answer.")
    }

    func testMarkdownPrefersCleanStandardOutputOverRawTranscriptText() {
        let output = CodexSessionOutput(
            state: .completed,
            text: "codex\nRaw transcript answer",
            standardOutput: "Clean **answer**"
        )

        XCTAssertEqual(CodexSessionOutputFormatter.markdown(from: output), "Clean **answer**")
    }
}
