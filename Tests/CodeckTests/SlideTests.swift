@testable import Codeck
@testable import CodeckCore
import XCTest

final class SlideTests: XCTestCase {
    func testTitleUsesFirstNonEmptyHeading() {
        let slide = Slide(
            markdown:
            """
            Intro text

            ###

            ## Actual Title
            """
        )

        XCTAssertEqual(slide.title, "Actual Title")
    }

    func testTitleFallsBackWhenSlideHasNoHeadingText() {
        let slide = Slide(
            markdown:
            """
            ###

            Plain content
            """
        )

        XCTAssertEqual(slide.title, "Untitled Slide")
    }

    func testSummaryUsesFirstNonHeadingContentLine() {
        let slide = Slide(
            markdown:
            """
            # Demo

            First useful summary line.

            - More detail
            """
        )

        XCTAssertEqual(slide.summary, "First useful summary line.")
    }

    func testSummaryFallsBackForPlainMarkdownWithoutBodyText() {
        let slide = Slide(markdown: "# Demo")

        XCTAssertEqual(slide.summary, "Markdown slide")
    }
}
