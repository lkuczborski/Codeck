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
    XCTAssertEqual(blocks[0].title, "Codex Session")
    XCTAssertEqual(blocks[0].prompt, "Explain this code.")
  }

  func testCodexTitleIsSeparateFromPrompt() {
    let blocks = CodexBlock.extract(
      from:
        """
        ```codex id=session
        title: Explain the refactor goal

        Rewrite this view into smaller SwiftUI subviews.
        ```
        """
    )

    XCTAssertEqual(blocks.first?.title, "Explain the refactor goal")
    XCTAssertEqual(blocks.first?.prompt, "Rewrite this view into smaller SwiftUI subviews.")
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

  func testRendererShowsPromptOnceAndAddsCodexBlockButton() {
    let prompt = "Rewrite this view into smaller SwiftUI subviews."
    let slide = Slide(
      markdown:
        """
        ```codex id=session
        title: Explain the refactor goal

        \(prompt)
        ```
        """
    )

    let html = MarkdownRenderer.htmlDocument(for: slide, theme: .studio, codexOutputs: [:])

    XCTAssertTrue(html.contains("Explain the refactor goal"))
    XCTAssertEqual(html.components(separatedBy: prompt).count - 1, 1)
    XCTAssertTrue(html.contains("Codeck.runCodex('session')"))
    XCTAssertFalse(html.contains("Codeck.runAllCodex()"))
  }

  func testRendererAddsRunAllForMultipleCodexBlocks() {
    let slide = Slide(
      markdown:
        """
        ```codex id=one
        title: First

        First prompt.
        ```

        ```codex id=two
        title: Second

        Second prompt.
        ```
        """
    )

    let html = MarkdownRenderer.htmlDocument(for: slide, theme: .studio, codexOutputs: [:])

    XCTAssertTrue(html.contains("Codeck.runAllCodex()"))
  }
}
