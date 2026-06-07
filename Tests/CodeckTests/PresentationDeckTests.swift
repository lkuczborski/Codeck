@testable import Codeck
@testable import CodeckCore
import SwiftUI
import XCTest

final class PresentationDeckTests: XCTestCase {
  func testDefaultDeckStartsWithEditableTitlePlaceholder() {
    let deck = PresentationDeck.blank

    XCTAssertEqual(deck.slides.count, 1)
    XCTAssertEqual(deck.slides[0].markdown, "# ")
    XCTAssertEqual(PresentationDeck.defaultSlideCursorLocation, 2)
  }

  func testNewPresentationDocumentStartsWithDefaultDeck() {
    let document = PresentationDocument()

    XCTAssertEqual(document.deck.slides.count, 1)
    XCTAssertEqual(document.deck.slides[0].markdown, "# ")
  }

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

  func testSampleDeckExercisesMarkdownCodexAndCodeSlideTypes() {
    let sample = PresentationDeck.sample

    XCTAssertEqual(sample.slides.map(\.title), ["Prompting Codex Live", "Live Codex Block", "Rich Markdown"])
    XCTAssertTrue(sample.slides[0].markdown.contains("| Slide part | Purpose |"))
    XCTAssertEqual(sample.slides[1].codexBlocks.count, 1)
    XCTAssertTrue(sample.slides[2].markdown.contains("```swift"))
  }

  func testAddsTemplateSlideAfterSelectedSlide() {
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# One")])
    let firstID = deck.slides[0].id

    let templateID = deck.addSlide(after: firstID, markdown: "# Decision\n\n- Ship it")

    XCTAssertEqual(deck.slides.count, 2)
    XCTAssertEqual(deck.slides[1].id, templateID)
    XCTAssertEqual(deck.slides[1].markdown, "# Decision\n\n- Ship it")
  }

  func testAddSlideAppendsWhenSelectionIsMissing() {
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# One")])

    let newID = deck.addSlide(after: UUID(), markdown: "# Two")

    XCTAssertEqual(deck.slides.map(\.title), ["One", "Two"])
    XCTAssertEqual(deck.slides.last?.id, newID)
  }

  func testDuplicateSlideReturnsNilForMissingSelectionWithoutMutatingDeck() {
    var deck = PresentationDeck(theme: .studio, slides: [Slide(markdown: "# One")])

    let duplicateID = deck.duplicateSlide(UUID())

    XCTAssertNil(duplicateID)
    XCTAssertEqual(deck.slides.map(\.title), ["One"])
  }

  func testDeleteSlideKeepsOneSlideAndSelectsNeighbor() {
    let first = Slide(markdown: "# One")
    let second = Slide(markdown: "# Two")
    let third = Slide(markdown: "# Three")
    var deck = PresentationDeck(theme: .studio, slides: [first, second, third])

    let selectedAfterMiddleDelete = deck.deleteSlide(second.id)

    XCTAssertEqual(selectedAfterMiddleDelete, third.id)
    XCTAssertEqual(deck.slides.map(\.title), ["One", "Three"])

    let selectedAfterLastDelete = deck.deleteSlide(third.id)

    XCTAssertEqual(selectedAfterLastDelete, first.id)
    XCTAssertEqual(deck.slides.map(\.title), ["One"])

    let selectedAfterOnlySlideDelete = deck.deleteSlide(first.id)

    XCTAssertEqual(selectedAfterOnlySlideDelete, first.id)
    XCTAssertEqual(deck.slides.map(\.title), ["One"])
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

  func testReadsLegacyRootLevelCodexMetadataKeys() {
    let deck = PresentationDeck(
      markdownDocument:
      """
      ---
      theme: solar
      model: "future-model"
      reasoning_effort: ultra
      sandbox: workspace-write
      ---

      # Defaults
      """
    )

    XCTAssertEqual(deck.theme, .solar)
    XCTAssertEqual(deck.settings.codex.model, "future-model")
    XCTAssertEqual(deck.settings.codex.reasoning.rawValue, "ultra")
    XCTAssertEqual(deck.settings.codex.sandbox, "workspace-write")
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

  func testTemplateCatalogUsesExpectedSectionsAndOrder() {
    XCTAssertEqual(SlideTemplateCatalog.sections.map(\.id), ["story", "planning", "demo-teaching"])
    XCTAssertEqual(SlideTemplateCatalog.sections.map(\.title), ["Story and Framing", "Planning and Decisions", "Demo and Teaching"])
    XCTAssertEqual(
      SlideTemplateCatalog.sections.map { $0.templates.map(\.id) },
      [
        ["opening-promise", "problem-framing", "big-number", "customer-quote"],
        ["decision-matrix", "roadmap", "risk-radar", "before-after"],
        ["demo-runbook", "code-walkthrough", "live-investigation", "workshop-exercise"],
      ]
    )
    XCTAssertEqual(SlideTemplateCatalog.defaultTemplate?.id, "opening-promise")
  }

  func testOpeningPromiseTemplate() throws {
    try assertTemplate(
      "opening-promise",
      name: "Opening Promise",
      description: "Start with the deck title and the value it promises.",
      markdown:
      """
      # Presentation Title

      A compact promise for what the audience will understand, decide, or be able to do by the end.
      """
    )
  }

  func testProblemFramingTemplate() throws {
    try assertTemplate(
      "problem-framing",
      name: "Problem Framing",
      description: "Name the tension before introducing the answer.",
      markdown:
      """
      # The Problem

      > The current workflow forces the team to spend attention in the wrong place.

      - Who feels it most
      - Where it appears in the work
      - Why it matters now
      """
    )
  }

  func testBigNumberTemplate() throws {
    try assertTemplate(
      "big-number",
      name: "Big Number",
      description: "Anchor a section around one metric and its implication.",
      markdown:
      """
      # One Number to Remember

      ## 42%

      What changed, why it matters, and which decision this number should influence.
      """
    )
  }

  func testCustomerQuoteTemplate() throws {
    try assertTemplate(
      "customer-quote",
      name: "Customer Quote",
      description: "Use a direct voice or memorable observation as evidence.",
      markdown:
      """
      # Voice of the Customer

      > "The moment it clicked was when the work stopped feeling like setup and started feeling like progress."

      Segment, source, or interview context
      """
    )
  }

  func testDecisionMatrixTemplate() throws {
    try assertTemplate(
      "decision-matrix",
      name: "Decision Matrix",
      description: "Compare a few options against the criteria that matter.",
      markdown:
      """
      # Decision Matrix

      | Option | Best for | Risk | Recommendation |
      | --- | --- | --- | --- |
      | A | Fast learning | Manual follow-up | Short-term |
      | B | Durable workflow | More implementation | Preferred |
      """
    )
  }

  func testRoadmapTemplate() throws {
    try assertTemplate(
      "roadmap",
      name: "Roadmap",
      description: "Show a sequence of phases without turning it into a table.",
      markdown:
      """
      # Roadmap

      1. **Now:** Validate the core workflow with real content.
      2. **Next:** Remove the largest source of manual cleanup.
      3. **Later:** Automate the repeatable path and measure adoption.
      """
    )
  }

  func testRiskRadarTemplate() throws {
    try assertTemplate(
      "risk-radar",
      name: "Risk Radar",
      description: "Separate risks, mitigations, and the ask.",
      markdown:
      """
      # Risk Radar

      **Primary risk:** The team optimizes the wrong part of the workflow.

      - Watch for: slow review cycles and repeated handoffs
      - Mitigate with: one owner and one validation checkpoint
      - Ask today: approve the next experiment
      """
    )
  }

  func testBeforeAfterTemplate() throws {
    try assertTemplate(
      "before-after",
      name: "Before and After",
      description: "Make a process or product improvement easy to scan.",
      markdown:
      """
      # Before and After

      ## Before

      The old path, constraint, or user experience.

      ***

      ## After

      The improved path and the reason it matters.
      """
    )
  }

  func testDemoRunbookTemplate() throws {
    try assertTemplate(
      "demo-runbook",
      name: "Demo Runbook",
      description: "Keep a live demo focused on the beats that matter.",
      markdown:
      """
      # Demo Runbook

      1. **Setup:** Start from the smallest believable example.
      2. **Show:** Perform the action the audience cares about.
      3. **Prove:** Check the result or compare before and after.
      4. **Fallback:** Know what to show if the live path fails.
      """
    )
  }

  func testCodeWalkthroughTemplate() throws {
    try assertTemplate(
      "code-walkthrough",
      name: "Code Walkthrough",
      description: "Explain a small implementation detail with context.",
      markdown:
      """
      # Code Walkthrough

      The important part is how the boundary stays explicit.

      ```swift
      struct SlideStep {
        let goal: String
        let evidence: String
      }
      ```
      """
    )
  }

  func testLiveInvestigationTemplate() throws {
    try assertTemplate(
      "live-investigation",
      name: "Live Investigation",
      description: "Ask Codex to inspect, explain, or test something live.",
      markdown:
      """
      # Live Investigation

      ```codex id=investigate
      title: Inspect the current state

      Review the relevant files and explain what is happening, what is risky, and what should be verified next.
      ```
      """
    )
  }

  func testWorkshopExerciseTemplate() throws {
    try assertTemplate(
      "workshop-exercise",
      name: "Workshop Exercise",
      description: "Give the audience a clear task and success criteria.",
      markdown:
      """
      # Workshop Exercise

      **Scenario:** A user needs to complete the workflow without reading documentation.

      - Define the first action they should take
      - Identify the feedback they need
      - Share one improvement you would make
      """
    )
  }

  @MainActor
  func testSlideCommandsCanDuplicateRepeatedlyFromLatestSelectedSlide() throws {
    let firstSlide = Slide(markdown: "# One")
    var document = PresentationDocument(deck: PresentationDeck(theme: .studio, slides: [firstSlide]))
    var selectedSlideIDString: String? = firstSlide.id.uuidString
    let commands = SlideCommandActions(
      document: Binding(
        get: { document },
        set: { document = $0 }
      ),
      selectedSlideIDString: Binding(
        get: { selectedSlideIDString },
        set: { selectedSlideIDString = $0 }
      )
    )

    commands.duplicateSlide()
    let firstCopyID = try XCTUnwrap(selectedSlideIDString.flatMap(UUID.init(uuidString:)))

    commands.duplicateSlide()
    let secondCopyID = try XCTUnwrap(selectedSlideIDString.flatMap(UUID.init(uuidString:)))

    XCTAssertEqual(document.deck.slides.count, 3)
    XCTAssertEqual(document.deck.slides.map(\.title), ["One", "One", "One"])
    XCTAssertEqual(document.deck.slides[1].id, firstCopyID)
    XCTAssertEqual(document.deck.slides[2].id, secondCopyID)
  }

  @MainActor
  func testSlideCommandsRecoverFromInvalidStoredSelection() throws {
    let firstSlide = Slide(markdown: "# One")
    var document = PresentationDocument(deck: PresentationDeck(theme: .studio, slides: [firstSlide]))
    var selectedSlideIDString: String? = UUID().uuidString
    let commands = SlideCommandActions(
      document: Binding(
        get: { document },
        set: { document = $0 }
      ),
      selectedSlideIDString: Binding(
        get: { selectedSlideIDString },
        set: { selectedSlideIDString = $0 }
      )
    )

    commands.addSlide()
    let addedSlideID = try XCTUnwrap(selectedSlideIDString.flatMap(UUID.init(uuidString:)))

    XCTAssertEqual(document.deck.slides.count, 2)
    XCTAssertEqual(document.deck.slides[1].id, addedSlideID)
    XCTAssertEqual(document.deck.slides[1].markdown, PresentationDeck.defaultSlideMarkdown)
  }

  @MainActor
  func testSlideCommandsAddTemplateSlideAndSelectIt() throws {
    let firstSlide = Slide(markdown: "# One")
    let template = try XCTUnwrap(SlideTemplateCatalog.template(withID: "live-investigation"))
    var document = PresentationDocument(deck: PresentationDeck(theme: .studio, slides: [firstSlide]))
    var selectedSlideIDString: String? = firstSlide.id.uuidString
    let commands = SlideCommandActions(
      document: Binding(
        get: { document },
        set: { document = $0 }
      ),
      selectedSlideIDString: Binding(
        get: { selectedSlideIDString },
        set: { selectedSlideIDString = $0 }
      )
    )

    commands.addSlide(from: template)
    let addedSlideID = try XCTUnwrap(selectedSlideIDString.flatMap(UUID.init(uuidString:)))

    XCTAssertEqual(document.deck.slides.count, 2)
    XCTAssertEqual(document.deck.slides[1].id, addedSlideID)
    XCTAssertEqual(document.deck.slides[1].markdown, template.markdown)
  }

  private func assertTemplate(
    _ id: String,
    name: String,
    description: String,
    markdown: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let template = try XCTUnwrap(SlideTemplateCatalog.template(withID: id), file: file, line: line)

    XCTAssertEqual(template.name, name, file: file, line: line)
    XCTAssertEqual(template.description, description, file: file, line: line)
    XCTAssertEqual(template.markdown, markdown, file: file, line: line)
  }
}
