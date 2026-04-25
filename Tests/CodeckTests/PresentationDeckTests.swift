import XCTest
@testable import Codeck

final class PresentationDeckTests: XCTestCase {
  func testParsesThemeAndSlideSeparatorsOutsideFences() {
    let deck = PresentationDeck(
      markdownDocument:
        """
        <!-- codeck-theme: chalk -->

        # One

        ```swift
        let separator = "---"
        ```

        ---

        # Two
        """
    )

    XCTAssertEqual(deck.theme, .chalk)
    XCTAssertEqual(deck.slides.count, 2)
    XCTAssertTrue(deck.slides[0].markdown.contains("separator"))
    XCTAssertEqual(deck.slides[1].title, "Two")
  }

  func testSerializesThemeMetadata() {
    let deck = PresentationDeck(theme: .atelier, slides: [Slide(markdown: "# Lesson")])

    XCTAssertTrue(deck.markdownDocument.hasPrefix("<!-- codeck-theme: atelier -->"))
    XCTAssertTrue(deck.markdownDocument.contains("# Lesson"))
  }
}
