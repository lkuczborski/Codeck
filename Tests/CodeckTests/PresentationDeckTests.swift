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

  func testParsesSlideDelimitersAfterStrictClosingFence() {
    let deck = PresentationDeck(
      markdownDocument:
        """
        ---
        format: codeck.mdeck
        version: 1
        theme: midnight
        codex:
          sandbox: read-only
          model: "gpt-5.5"
          reasoning: medium
        ---
        # Live Codex Blocks

        ```codex id=first-demo
        title: First example

        Explain three practical ways to make a prompt more testable.
        ``d`

        ```codex id=second-demo
        title: Second example

        What is the best reasoning effort for GPT-5.5?
        ```

        ---

        # Live Codex Block

        ```codex id=first-demo
        title: First example

        Explain three practical ways to make a prompt more testable.
        ```

        ---

        # Rich Markdown

        ```swift
        struct Lesson {
          let separator = "---"
        }
        ```

        ---

        # New Slide
        """
    )

    XCTAssertEqual(deck.theme, .midnight)
    XCTAssertEqual(deck.slides.count, 4)
    XCTAssertEqual(deck.slides.map(\.title), ["Live Codex Blocks", "Live Codex Block", "Rich Markdown", "New Slide"])
    XCTAssertTrue(deck.slides[0].markdown.contains("```codex id=second-demo"))
  }

  func testSerializesThemeMetadata() {
    let deck = PresentationDeck(
      settings: PresentationSettings(
        theme: .atelier,
        codex: DeckCodexSettings(
          model: "gpt-5.2",
          reasoning: .medium,
          sandbox: "read-only"
        )
      ),
      slides: [Slide(markdown: "# Lesson")]
    )

    XCTAssertTrue(deck.deckDocument.hasPrefix("---\nformat: codeck.mdeck"))
    XCTAssertTrue(deck.deckDocument.contains("theme: atelier"))
    XCTAssertTrue(deck.deckDocument.contains("  model: \"gpt-5.2\""))
    XCTAssertTrue(deck.deckDocument.contains("  reasoning: medium"))
    XCTAssertTrue(deck.deckDocument.contains("# Lesson"))
  }

  func testAddedSlidesRoundTripThroughDeckDocument() {
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# One")])
    let firstID = deck.slides[0].id

    let secondID = deck.addSlide(after: firstID)
    deck.slides[1].markdown = "# Two\n\nSecond slide"
    _ = deck.addSlide(after: secondID)
    deck.slides[2].markdown = "# Three\n\nThird slide"

    let reopened = PresentationDeck(markdownDocument: deck.deckDocument)

    XCTAssertEqual(reopened.slides.count, 3)
    XCTAssertEqual(reopened.slides.map(\.title), ["One", "Two", "Three"])
    XCTAssertTrue(deck.deckDocument.contains("\n\n---\n\n# Two"))
    XCTAssertTrue(deck.deckDocument.contains("\n\n---\n\n# Three"))
  }

  func testReplacingSlideMarkdownSplitsSlideDelimiters() {
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# One")])
    let firstID = deck.slides[0].id

    let result = deck.replaceSlideMarkdown(
      for: firstID,
      with:
        """
        # One

        ---

        # Two

        ---

        # Three
        """
    )

    XCTAssertEqual(deck.slides.count, 3)
    XCTAssertEqual(deck.slides[0].id, firstID)
    XCTAssertEqual(deck.slides.map(\.title), ["One", "Two", "Three"])
    XCTAssertEqual(result?.selectedSlideID, deck.slides[1].id)
    XCTAssertEqual(result?.didSplit, true)
  }

  func testReplacingSlideMarkdownKeepsDelimitersInsideFences() {
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# Demo")])
    let firstID = deck.slides[0].id

    let result = deck.replaceSlideMarkdown(
      for: firstID,
      with:
        """
        # Demo

        ```swift
        let separator = "---"
        ```
        """
    )

    XCTAssertEqual(deck.slides.count, 1)
    XCTAssertTrue(deck.slides[0].markdown.contains("separator"))
    XCTAssertEqual(result?.selectedSlideID, firstID)
    XCTAssertEqual(result?.didSplit, false)
  }

  func testReplacingSlideMarkdownKeepsSeparatorLinesInsideFences() {
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# Demo")])
    let firstID = deck.slides[0].id

    let result = deck.replaceSlideMarkdown(
      for: firstID,
      with:
        """
        # Demo

        ```yaml
        ---
        name: fixture
        ---
        ```
        """
    )

    XCTAssertEqual(deck.slides.count, 1)
    XCTAssertTrue(deck.slides[0].markdown.contains("name: fixture"))
    XCTAssertEqual(result?.selectedSlideID, firstID)
    XCTAssertEqual(result?.didSplit, false)
  }

  func testReplacingSlideMarkdownCreatesDefaultSlideForTrailingDelimiter() {
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# One")])
    let firstID = deck.slides[0].id

    let result = deck.replaceSlideMarkdown(
      for: firstID,
      with:
        """
        # One

        ---
        """
    )

    XCTAssertEqual(deck.slides.count, 2)
    XCTAssertEqual(deck.slides[0].title, "One")
    XCTAssertEqual(deck.slides[1].markdown, PresentationDeck.defaultSlideMarkdown)
    XCTAssertEqual(result?.selectedSlideID, deck.slides[1].id)
    XCTAssertEqual(result?.didSplit, true)
  }

  func testUsesExplicitDefaultCodexSettingsWhenMetadataIsMissing() {
    let deck = PresentationDeck(
      markdownDocument:
        """
        # Defaults
        """
    )

    XCTAssertEqual(deck.settings.codex.model, "gpt-5.5")
    XCTAssertEqual(deck.settings.codex.reasoning, .medium)
    XCTAssertEqual(deck.settings.codex.sandbox, "read-only")
  }

  func testPreservesFutureModelAndReasoningMetadata() {
    let deck = PresentationDeck(
      markdownDocument:
        """
        ---
        format: codeck.mdeck
        version: 1
        theme: studio
        codex:
          model: old-model
          reasoning: unexpected
        ---

        # Defaults
        """
    )

    XCTAssertEqual(deck.settings.codex.model, "old-model")
    XCTAssertEqual(deck.settings.codex.reasoning.rawValue, "unexpected")
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

  func testInsertedCodexBlockIncludesDefaultTitle() {
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# Demo")])
    let slideID = deck.slides[0].id

    deck.insertCodexBlock(into: slideID)

    XCTAssertTrue(deck.slides[0].markdown.contains("```codex id=demo-1"))
    XCTAssertTrue(deck.slides[0].markdown.contains("title: Describe the goal for this prompt"))
  }
}
