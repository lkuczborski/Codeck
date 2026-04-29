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

  func testCodexBlockIgnoresLegacyVerboseFlag() {
    let blocks = CodexBlock.extract(
      from:
        """
        ```codex id=session
        verbose: true

        Show the raw session transcript.
        ```
        """
    )

    XCTAssertEqual(blocks.first?.prompt, "Show the raw session transcript.")
  }

  func testCodexFenceRequiresPlainClosingFence() {
    let blocks = CodexBlock.extract(
      from:
        """
        ```codex id=first
        title: First

        First prompt
        ``d`

        ```codex id=second
        title: This is code content

        Second prompt text
        ```
        """
    )

    XCTAssertEqual(blocks.count, 1)
    XCTAssertEqual(blocks[0].id, "first")
    XCTAssertTrue(blocks[0].prompt.contains("```codex id=second"))
    XCTAssertTrue(blocks[0].prompt.contains("Second prompt text"))
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

  func testRendererHighlightsFencedCodeByLanguage() {
    let slide = Slide(
      markdown:
        #"""
        ```swift
        struct DemoView: View {
          let title = "Hello"
        }
        ```
        """#
    )

    let html = MarkdownRenderer.htmlDocument(for: slide, theme: .studio, codexOutputs: [:])

    XCTAssertTrue(html.contains("<code class=\"language-swift\">"))
    XCTAssertTrue(html.contains("<span class=\"syntax-keyword\">struct</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-type\">DemoView</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-type\">View</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-string\">&quot;Hello&quot;</span>"))
  }

  func testRendererUsesFirstFenceInfoTokenAsLanguage() {
    let slide = Slide(
      markdown:
        #"""
        ```swift title="Example"
        let count = 3
        ```
        """#
    )

    let html = MarkdownRenderer.htmlDocument(for: slide, theme: .studio, codexOutputs: [:])

    XCTAssertTrue(html.contains("<code class=\"language-swift\">"))
    XCTAssertFalse(html.contains("language-swift title"))
    XCTAssertTrue(html.contains("<span class=\"syntax-keyword\">let</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-number\">3</span>"))
  }

  func testRendererRequiresPlainClosingFence() {
    let slide = Slide(
      markdown:
        #"""
        ```swift
        let first = true
        ```javascript
        const second = true
        ```
        """#
    )

    let html = MarkdownRenderer.htmlDocument(for: slide, theme: .studio, codexOutputs: [:])

    XCTAssertEqual(html.components(separatedBy: "<pre><code").count - 1, 1)
    XCTAssertFalse(html.contains("language-javascript"))
    XCTAssertTrue(html.contains("javascript"))
    XCTAssertTrue(html.contains("second"))
  }

  func testRendererHighlightsDifferentFenceLanguagesAndEscapesCode() {
    let slide = Slide(
      markdown:
        #"""
        ```json
        { "enabled": true, "count": 2 }
        ```

        ```html
        <script type="module">alert("nope")</script>
        ```
        """#
    )

    let html = MarkdownRenderer.htmlDocument(for: slide, theme: .studio, codexOutputs: [:])

    XCTAssertTrue(html.contains("<code class=\"language-json\">"))
    XCTAssertTrue(html.contains("<span class=\"syntax-property\">&quot;enabled&quot;</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-literal\">true</span>"))
    XCTAssertTrue(html.contains("<code class=\"language-html\">"))
    XCTAssertTrue(html.contains("&lt;"))
    XCTAssertFalse(html.contains("<script type=\"module\">"))
  }

  func testRendererShowsOnlyCodexResponseByDefaultAndRendersMarkdown() {
    let slide = Slide(
      markdown:
        """
        ```codex id=session
        title: Explain output

        Prompt
        ```
        """
    )
    let output =
      """
      OpenAI Codex
      user
      Prompt
      codex
      # Result

      - **One**
      - `Two`
      """

    let html = MarkdownRenderer.htmlDocument(
      for: slide,
      theme: .studio,
      codexOutputs: [
        "session": CodexSessionOutput(state: .completed, text: output)
      ]
    )

    XCTAssertFalse(html.contains("OpenAI Codex"))
    XCTAssertFalse(html.contains("<pre class=\"codex-output\">"))
    XCTAssertTrue(html.contains("<h1>Result</h1>"))
    XCTAssertTrue(html.contains("<strong>One</strong>"))
    XCTAssertTrue(html.contains("<code>Two</code>"))
  }

  func testRendererRendersStrikethroughInlineMarkdown() {
    let slide = Slide(markdown: "Keep ~~remove~~ revise.")

    let html = MarkdownRenderer.htmlDocument(for: slide, theme: .studio, codexOutputs: [:])

    XCTAssertTrue(html.contains("Keep <del>remove</del> revise."))
  }

  func testRendererStreamsRunningCodexTranscriptResponse() {
    let slide = Slide(
      markdown:
        """
        ```codex id=session
        title: Explain output

        Prompt
        ```
        """
    )
    let output =
      """
      user
      Prompt
      codex Streaming **partial**
      """

    let html = MarkdownRenderer.htmlDocument(
      for: slide,
      theme: .studio,
      codexOutputs: [
        "session": CodexSessionOutput(
          state: .running,
          text: output,
          standardError: output
        )
      ]
    )

    XCTAssertFalse(html.contains("Thinking..."))
    XCTAssertTrue(html.contains("Streaming <strong>partial</strong>"))
  }

  func testRendererStreamsRunningCodexStandardOutput() {
    let slide = Slide(
      markdown:
        """
        ```codex id=session
        title: Explain output

        Prompt
        ```
        """
    )

    let html = MarkdownRenderer.htmlDocument(
      for: slide,
      theme: .studio,
      codexOutputs: [
        "session": CodexSessionOutput(
          state: .running,
          text: "",
          standardOutput: "Streaming **partial**"
        )
      ]
    )

    XCTAssertFalse(html.contains("Thinking..."))
    XCTAssertTrue(html.contains("Streaming <strong>partial</strong>"))
  }

  func testRendererShowsThinkingPlaceholderForEmptyRunningCodexOutput() {
    let slide = Slide(
      markdown:
        """
        ```codex id=session
        title: Explain output

        Prompt
        ```
        """
    )

    let html = MarkdownRenderer.htmlDocument(
      for: slide,
      theme: .studio,
      codexOutputs: [
        "session": CodexSessionOutput(state: .running, text: "")
      ]
    )

    XCTAssertTrue(html.contains("Thinking..."))
    XCTAssertFalse(html.contains("Waiting for Codex response"))
  }

  func testCodexMarkdownOutputKeepsLooseOrderedListTogether() {
    let slide = Slide(
      markdown:
        """
        ```codex id=session
        title: Prompt tactics

        Prompt
        ```
        """
    )
    let output =
      """
      codex
      1. **Define observable behavior**

      Say what should change.

      > Improve validation.

      1. **Name the tests Codex should run**

      Give a concrete verification target.

      > npm test

      1. **Constrain scope**

      State what counts as done.
      """

    let html = MarkdownRenderer.htmlDocument(
      for: slide,
      theme: .studio,
      codexOutputs: [
        "session": CodexSessionOutput(state: .completed, text: output)
      ]
    )

    XCTAssertEqual(html.components(separatedBy: "<ol>").count - 1, 1)
    XCTAssertEqual(html.components(separatedBy: "<li>").count - 1, 3)
    XCTAssertTrue(html.contains("<strong>Name the tests Codex should run</strong>"))
    XCTAssertTrue(html.contains("<blockquote>npm test</blockquote>"))
  }

  func testRendererPrefersCleanFinalCodexOutputOverTranscriptCopy() {
    let slide = Slide(
      markdown:
        """
        ```codex id=session
        title: Prompt tactics

        Prompt
        ```
        """
    )
    let response =
      """
      Three practical ways:

      1. **Define observable behavior**

      Say what should change.

      1. **Name the expected tests or checks**

      Tell Codex what should pass.
      """
    let transcript =
      """
      user
      Prompt
      codex
      \(response)
      tokens used 10,784
      """

    let html = MarkdownRenderer.htmlDocument(
      for: slide,
      theme: .studio,
      codexOutputs: [
        "session": CodexSessionOutput(
          state: .completed,
          text: transcript + response,
          standardOutput: response,
          standardError: transcript
        )
      ]
    )

    XCTAssertFalse(html.contains("tokens used"))
    XCTAssertEqual(html.components(separatedBy: "Define observable behavior").count - 1, 1)
    XCTAssertEqual(html.components(separatedBy: "Name the expected tests or checks").count - 1, 1)
  }

  func testRendererTrimsCodexUsageFooterWhenOnlyTranscriptIsAvailable() {
    let slide = Slide(
      markdown:
        """
        ```codex id=session
        title: Prompt tactics

        Prompt
        ```
        """
    )
    let output =
      """
      codex
      Three practical ways:

      1. **Define observable behavior**

      Say what should change.
      tokens used 10,784 Three practical ways:

      1. **Define observable behavior**

      Say what should change.
      """

    let html = MarkdownRenderer.htmlDocument(
      for: slide,
      theme: .studio,
      codexOutputs: [
        "session": CodexSessionOutput(state: .completed, text: output)
      ]
    )

    XCTAssertFalse(html.contains("tokens used"))
    XCTAssertEqual(html.components(separatedBy: "Define observable behavior").count - 1, 1)
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
    XCTAssertTrue(html.contains("aria-label=\"Run Codex session\""))
    XCTAssertTrue(html.contains("class=\"play-icon\""))
    XCTAssertTrue(html.contains("display: flex;"))
    XCTAssertTrue(html.contains("align-items: center;"))
    XCTAssertTrue(html.contains("height: 1.42em;"))
    XCTAssertFalse(html.contains(">Codex Session</span>"))
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
    XCTAssertTrue(html.contains("aria-label=\"Run all Codex sessions\""))
    XCTAssertTrue(html.contains("class=\"run-all-icon\""))
    XCTAssertTrue(html.contains("line-height: 0;"))
    XCTAssertTrue(html.contains("transform: translateX(0.08em);"))
    XCTAssertTrue(html.contains("transform: translateY(-50%);"))
  }
}
