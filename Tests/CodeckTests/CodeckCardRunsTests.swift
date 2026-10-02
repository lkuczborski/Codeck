@testable import CodeckCore
import XCTest

final class CodeckCardRunsTests: XCTestCase {
    private func workspace(_ source: String, id: String = "deck") -> DeckWorkspace {
        DeckWorkspace(id: id, title: "Test", markdown: source, path: nil, revision: 0, savedDigest: nil, diskConflict: false, updatedAt: Date())
    }

    func testCardsUseSolLightThenDeckThenFenceOverrides() throws {
        let runs = CodeckCardRuns()
        let source = "# Slide\n```codex id=card\nExplain this.\n```"
        let fallback = try runs.begin(workspace: workspace(source), slideIndex: 0, blockID: "card")
        XCTAssertEqual(fallback.model, "gpt-6.1-sol")
        XCTAssertEqual(fallback.reasoning, "low")
        let metadata = "---\ncodex:\n  model: gpt-6-astra\n  reasoning: high\n---\n"
        let deck = try runs.begin(workspace: workspace(metadata + source), slideIndex: 0, blockID: "card")
        XCTAssertEqual(deck.model, "gpt-6-astra")
        XCTAssertEqual(deck.reasoning, "high")
        let overridden = source.replacingOccurrences(of: "id=card", with: "id=card model=gpt-6-luna reasoning=max")
        let fence = try runs.begin(workspace: workspace(metadata + overridden), slideIndex: 0, blockID: "card")
        XCTAssertEqual(fence.model, "gpt-6-luna")
        XCTAssertEqual(fence.reasoning, "max")
        XCTAssertEqual(runs.run(deck.id)?.status, "stopped")
    }

    func testRunIdentityPreventsLateResultsAndCrossWorkspaceContamination() throws {
        let runs = CodeckCardRuns()
        let source = "```codex id=card\nExplain this.\n```"
        let state = workspace(source)
        let first = try runs.begin(workspace: state, slideIndex: 0, blockID: "card")
        XCTAssertEqual(try runs.begin(workspace: state, slideIndex: 0, blockID: "card").id, first.id)
        let other = try runs.begin(workspace: workspace(source, id: "other"), slideIndex: 0, blockID: "card")
        XCTAssertNotEqual(first.id, other.id)
        runs.updateNative(first.id, output: CodexSessionOutput(state: .completed, text: "Result"))
        let blocks = PresentationDeck(markdownDocument: source).slides[0].codexBlocks
        XCTAssertEqual(runs.outputs("deck", blocks: blocks)["card"]?.text, "Result")
        XCTAssertEqual(runs.outputs("other", blocks: blocks)["card"]?.text, "")
        let next = try runs.begin(workspace: state, slideIndex: 0, blockID: "card")
        runs.stop(next.id)
        runs.updateNative(next.id, output: CodexSessionOutput(state: .completed, text: "Late"))
        XCTAssertEqual(runs.run(next.id)?.status, "stopped")
        XCTAssertEqual(runs.run(next.id)?.output, "")
        let changed = PresentationDeck(markdownDocument: source.replacingOccurrences(of: "Explain this.", with: "Different prompt.")).slides[0].codexBlocks
        XCTAssertTrue(runs.outputs("deck", blocks: changed).isEmpty)
    }

    func testProtocolDiagnosticsNeverAppearAsCardResponses() throws {
        let runs = CodeckCardRuns()
        let run = try runs.begin(workspace: workspace("```codex id=card\nPrompt\n```"), slideIndex: 0, blockID: "card")
        let diagnostic = #"{"method":"thread/started","params":{"id":"private-protocol-id"}}"#
        runs.updateNative(run.id, output: CodexSessionOutput(state: .running, text: diagnostic, standardError: diagnostic))
        XCTAssertEqual(runs.run(run.id)?.output, "Thinking...")
        runs.updateNative(
            run.id,
            output: CodexSessionOutput(state: .running, text: diagnostic + "\nAnswer", standardOutput: "Answer", standardError: diagnostic)
        )
        XCTAssertEqual(runs.run(run.id)?.output, "Answer")
        // A model deliberately answering in JSON is still a valid response.
        let answer = #"{"answer":4}"#
        runs.updateNative(run.id, output: CodexSessionOutput(state: .completed, text: diagnostic + answer, standardOutput: answer, standardError: diagnostic))
        XCTAssertEqual(runs.run(run.id)?.output, answer)
    }

    func testDuplicateAndMissingIDsCannotLaunch() throws {
        let runs = CodeckCardRuns()
        let card = "```codex id=card\nPrompt\n```"
        XCTAssertThrowsError(try runs.begin(workspace: workspace(card + "\n---\n" + card), slideIndex: 0, blockID: "card"))
        XCTAssertThrowsError(try runs.begin(workspace: workspace(card), slideIndex: 0, blockID: "missing"))
        XCTAssertThrowsError(try runs.begin(workspace: workspace(card), slideIndex: 1, blockID: "card"))
    }
}
