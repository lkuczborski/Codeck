@testable import Codeck
@testable import CodeckCore
import XCTest

final class DeckAssistantTests: XCTestCase {
    func testPromptIncludesDeckContextSelectedSlideAndWebMode() {
        let deck = PresentationDeck(
            settings: .default,
            slides: [
                Slide(markdown: "# Intro\n\nOld framing."),
                Slide(markdown: "# Evidence\n\nNeeds data."),
            ]
        )

        let prompt = DeckAssistantPromptBuilder.prompt(
            goal: "Make this sharper.",
            scope: .currentSlide,
            allowsWebResearch: true,
            deck: deck,
            selectedSlideIndex: 1,
            currentDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(prompt.contains("Make this sharper."))
        XCTAssertTrue(prompt.contains("Web research:\nEnabled."))
        XCTAssertTrue(prompt.contains("Selected slide:\nindex: 1"))
        XCTAssertTrue(prompt.contains("Deck outline:"))
        XCTAssertTrue(prompt.contains("1. Evidence - Needs data."))
        XCTAssertTrue(prompt.contains("<slide index=\"0\" title=\"Intro\">"))
        XCTAssertFalse(prompt.contains("<slide index=\"1\" title=\"Evidence\">"))
        XCTAssertTrue(prompt.contains("\"operation\": \"replace\""))
    }

    func testQuickPromptKeepsSlideScopeCompact() {
        let deck = PresentationDeck(
            settings: .default,
            slides: [
                Slide(markdown: "# Intro\n\nOpening summary.\n\nOpening private detail."),
                Slide(markdown: "# Evidence\n\nSelected summary.\n\nSelected private detail."),
                Slide(markdown: "# Nearby\n\nNeighbor summary.\n\nNeighbor private detail."),
                Slide(markdown: "# Appendix\n\nFar summary.\n\nFar private detail."),
            ]
        )

        let prompt = DeckAssistantPromptBuilder.prompt(
            goal: "Improve this slide.",
            scope: .currentSlide,
            allowsWebResearch: false,
            deck: deck,
            selectedSlideIndex: 1,
            currentDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(prompt.contains("Selected private detail."))
        XCTAssertTrue(prompt.contains("Neighbor private detail."))
        XCTAssertTrue(prompt.contains("3. Appendix - Far summary."))
        XCTAssertFalse(prompt.contains("Far private detail."))
        XCTAssertFalse(prompt.contains("<slide index=\"3\" title=\"Appendix\">"))
    }

    func testPromptForDisabledWebForbidsBrowsing() {
        let deck = PresentationDeck(settings: .default, slides: [Slide(markdown: "# Intro")])

        let prompt = DeckAssistantPromptBuilder.prompt(
            goal: DeckAssistantQuickAction.addResearch.prompt,
            scope: .wholeDeck,
            allowsWebResearch: false,
            deck: deck,
            selectedSlideIndex: nil,
            currentDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(prompt.contains("Web research:\nDisabled."))
        XCTAssertTrue(prompt.contains("Do not browse, search, fetch URLs"))
    }

    func testWholeDeckPromptDoesNotPrioritizeSelectedSlide() {
        let deck = PresentationDeck(
            settings: .default,
            slides: [
                Slide(markdown: "# Intro\n\nOpening."),
                Slide(markdown: "# Evidence\n\nNeeds support."),
                Slide(markdown: "# Close\n\nMissing next steps."),
            ]
        )

        let prompt = DeckAssistantPromptBuilder.prompt(
            goal: "Improve the deck.",
            scope: .wholeDeck,
            allowsWebResearch: false,
            deck: deck,
            selectedSlideIndex: 0,
            currentDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(prompt.contains("Selected slide: Not prioritized in Deck scope."))
        XCTAssertTrue(prompt.contains("Full deck:"))
        XCTAssertTrue(prompt.contains("<slide index=\"0\" title=\"Intro\">"))
        XCTAssertTrue(prompt.contains("<slide index=\"1\" title=\"Evidence\">"))
        XCTAssertTrue(prompt.contains("<slide index=\"2\" title=\"Close\">"))
        XCTAssertTrue(prompt.contains("Use \"insert\" to add missing context, evidence, transition, example, agenda, or closing slides."))
        XCTAssertTrue(prompt.contains("Do not limit proposals to rewriting slide 1"))
        XCTAssertFalse(prompt.contains("Prefer the selected slide"))
        XCTAssertFalse(prompt.contains("Nearby slide context:"))
    }

    func testWebOnlyQuickActionsRequireWebResearch() {
        XCTAssertFalse(DeckAssistantQuickAction.diagnose.requiresWebResearch)
        XCTAssertFalse(DeckAssistantQuickAction.shorten.requiresWebResearch)
        XCTAssertFalse(DeckAssistantQuickAction.professionalize.requiresWebResearch)
        XCTAssertTrue(DeckAssistantQuickAction.addResearch.requiresWebResearch)
        XCTAssertTrue(DeckAssistantQuickAction.addData.requiresWebResearch)
    }

    func testRunPolicyDisablesWebOnlyActionsWhenWebIsOff() {
        XCTAssertTrue(
            DeckAssistantRunPolicy.canRun(.diagnose, allowsWebResearch: false, isRunning: false)
        )
        XCTAssertFalse(
            DeckAssistantRunPolicy.canRun(.addResearch, allowsWebResearch: false, isRunning: false)
        )
        XCTAssertFalse(
            DeckAssistantRunPolicy.canRun(.addData, allowsWebResearch: false, isRunning: false)
        )
        XCTAssertTrue(
            DeckAssistantRunPolicy.canRun(.addResearch, allowsWebResearch: true, isRunning: false)
        )
        XCTAssertFalse(
            DeckAssistantRunPolicy.canRun(.diagnose, allowsWebResearch: true, isRunning: true)
        )
    }

    func testDeckFingerprintChangesForContentAndOrder() throws {
        let firstSlide = try Slide(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            markdown: "# Intro\n\nOpening."
        )
        let secondSlide = try Slide(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
            markdown: "# Evidence\n\nProof."
        )
        let deck = PresentationDeck(settings: .default, slides: [firstSlide, secondSlide])
        let originalFingerprint = DeckAssistantDeckContextCache.fingerprint(for: deck)

        let editedDeck = PresentationDeck(
            settings: .default,
            slides: [
                Slide(id: firstSlide.id, markdown: "# Intro\n\nEdited."),
                secondSlide,
            ]
        )
        let reorderedDeck = PresentationDeck(settings: .default, slides: [secondSlide, firstSlide])

        XCTAssertNotEqual(DeckAssistantDeckContextCache.fingerprint(for: editedDeck), originalFingerprint)
        XCTAssertNotEqual(DeckAssistantDeckContextCache.fingerprint(for: reorderedDeck), originalFingerprint)
    }

    func testParserBuildsReplacementAndInsertChangesFromFencedJSON() throws {
        let deck = PresentationDeck(
            settings: .default,
            slides: [
                Slide(markdown: "# Intro\n\nOld framing."),
                Slide(markdown: "# Evidence\n\nNeeds data."),
            ]
        )
        let response =
            """
            ```json
            {
              "title": "Sharpen the story",
              "summary": "Rewrite the weak evidence slide and add a proof slide.",
              "changes": [
                {
                  "id": "rewrite-evidence",
                  "title": "Rewrite evidence",
                  "detail": "Adds a clearer claim.",
                  "operation": "replace",
                  "slideIndex": 1,
                  "afterMarkdown": "# Evidence\\n\\nA sharper claim."
                },
                {
                  "id": "add-proof",
                  "title": "Add proof",
                  "detail": "Introduces supporting data.",
                  "operation": "insert",
                  "insertPosition": 2,
                  "afterMarkdown": "# Proof\\n\\n- Source-backed point"
                }
              ]
            }
            ```
            """

        let proposal = try DeckAssistantProposalParser.proposal(from: response, deck: deck)

        XCTAssertEqual(proposal.title, "Sharpen the story")
        XCTAssertEqual(proposal.summary, "Rewrite the weak evidence slide and add a proof slide.")
        XCTAssertEqual(proposal.changes.count, 2)
        XCTAssertEqual(proposal.changes[0].beforeMarkdown, "# Evidence\n\nNeeds data.")
        XCTAssertEqual(proposal.changes[0].afterMarkdown, "# Evidence\n\nA sharper claim.")
        XCTAssertEqual(proposal.changes[1].locationLabel, "Insert at 3")
    }

    func testParserRejectsResponsesWithoutValidChanges() {
        let deck = PresentationDeck(settings: .default, slides: [Slide(markdown: "# Intro")])
        let response =
            """
            {
              "title": "No-op",
              "summary": "Nothing useful.",
              "changes": [
                {
                  "id": "bad",
                  "title": "Bad",
                  "detail": "Out of range.",
                  "operation": "replace",
                  "slideIndex": 99,
                  "afterMarkdown": "# Missing"
                }
              ]
            }
            """

        XCTAssertThrowsError(try DeckAssistantProposalParser.proposal(from: response, deck: deck)) { error in
            XCTAssertEqual(error as? DeckAssistantProposalParseError, .noValidChanges)
        }
    }
}
