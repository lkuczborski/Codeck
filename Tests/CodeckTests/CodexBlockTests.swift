import XCTest
@testable import Codeck

final class CodexBlockTests: XCTestCase {
  func testExtractsCodexBlockMetadataAndPrompt() {
    let blocks = CodexBlock.extract(
      from:
        """
        # Demo

        ```codex id=demo-one
        sandbox: read-only
        model: gpt-5.2

        Explain this code.
        ```
        """
    )

    XCTAssertEqual(blocks.count, 1)
    XCTAssertEqual(blocks[0].id, "demo-one")
    XCTAssertEqual(blocks[0].sandbox, "read-only")
    XCTAssertEqual(blocks[0].model, "gpt-5.2")
    XCTAssertNil(blocks[0].reasoning)
    XCTAssertEqual(blocks[0].prompt, "Explain this code.")
  }

  func testRendererIncludesTablesImagesAndCodexOutput() {
    let slide = Slide(
      markdown:
        """
        # Assets

        ![Alt](Images/example.gif)

        | A | B |
        | --- | --- |
        | One | Two |

        ```codex id=session
        Prompt
        ```
        """
    )

    let html = MarkdownRenderer.htmlDocument(
      for: slide,
      theme: .studio,
      codexOutputs: [
        "session": CodexSessionOutput(state: .completed, text: "Done")
      ]
    )

    XCTAssertTrue(html.contains("<table>"))
    XCTAssertTrue(html.contains("<img src=\"Images/example.gif\" alt=\"Alt\">"))
    XCTAssertTrue(html.contains("Done"))
  }
}
