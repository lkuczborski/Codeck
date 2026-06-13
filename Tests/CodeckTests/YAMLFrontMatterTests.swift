@testable import Codeck
@testable import CodeckCore
import XCTest

final class YAMLFrontMatterTests: XCTestCase {
    func testParsesNestedSectionValuesAndUnquotesStrings() throws {
        let parsed = try XCTUnwrap(
            YAMLFrontMatter.parse(
                from:
                """

                ---
                # Deck metadata
                theme: 'solar'
                codex:
                  model: "gpt-5.5"
                  reasoning: high
                  sandbox: workspace-write
                ---
                # Slide
                """
            )
        )

        XCTAssertEqual(parsed.values["theme"], "solar")
        XCTAssertEqual(parsed.values["codex.model"], "gpt-5.5")
        XCTAssertEqual(parsed.values["codex.reasoning"], "high")
        XCTAssertEqual(parsed.values["codex.sandbox"], "workspace-write")
        XCTAssertEqual(parsed.body, "# Slide")
    }

    func testReturnsNilWhenOpeningOrClosingDelimiterIsMissing() {
        XCTAssertNil(YAMLFrontMatter.parse(from: "# Slide"))
        XCTAssertNil(
            YAMLFrontMatter.parse(
                from:
                """
                ---
                theme: studio
                # Slide
                """
            )
        )
    }
}
