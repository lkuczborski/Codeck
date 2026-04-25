import XCTest
@testable import Codeck

final class PresentationDeckTests: XCTestCase {
  func testParsesThemeAndSlideSeparatorsOutsideFences() {
    let deck = PresentationDeck(
      markdownDocument:
        """
        ---
        format: codeck.mdeck
        version: 1
        theme: chalk
        codex:
          model: gpt-5.2
          reasoning: high
          sandbox: workspace-write
        ---

        # One

        ```swift
        let separator = "---"
        ```

        ---

        # Two
        """
    )

    XCTAssertEqual(deck.theme, .chalk)
    XCTAssertEqual(deck.settings.codex.model, "gpt-5.2")
    XCTAssertEqual(deck.settings.codex.reasoning, .high)
    XCTAssertEqual(deck.settings.codex.sandbox, "workspace-write")
    XCTAssertEqual(deck.slides.count, 2)
    XCTAssertTrue(deck.slides[0].markdown.contains("separator"))
    XCTAssertEqual(deck.slides[1].title, "Two")
  }

  func testSerializesThemeMetadata() {
    let deck = PresentationDeck(
      settings: PresentationSettings(
        theme: .atelier,
        codex: DeckCodexSettings(
          model: "gpt-5.2",
          reasoning: .medium,
          profile: "teaching",
          sandbox: "read-only"
        )
      ),
      slides: [Slide(markdown: "# Lesson")]
    )

    XCTAssertTrue(deck.deckDocument.hasPrefix("---\nformat: codeck.mdeck"))
    XCTAssertTrue(deck.deckDocument.contains("theme: atelier"))
    XCTAssertTrue(deck.deckDocument.contains("  model: \"gpt-5.2\""))
    XCTAssertTrue(deck.deckDocument.contains("  reasoning: medium"))
    XCTAssertTrue(deck.deckDocument.contains("  profile: \"teaching\""))
    XCTAssertTrue(deck.deckDocument.contains("# Lesson"))
  }

  func testReadsLegacyMarkdownThemeComment() {
    let deck = PresentationDeck(
      markdownDocument:
        """
        <!-- codeck-theme: solar -->

        # Legacy
        """
    )

    XCTAssertEqual(deck.theme, .solar)
    XCTAssertEqual(deck.slides.first?.title, "Legacy")
  }
}
