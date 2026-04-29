import Foundation
import XCTest
@testable import Codeck

final class MarkdownEditorOperationTests: XCTestCase {
  func testBoldToggleWrapsSelectionAndReportsActiveStyle() {
    let text = "Hello world"
    let selection = NSRange(location: 6, length: 5)

    let wrapped = MarkdownEditorOperation.toggle(.bold, in: text, selection: selection)

    XCTAssertEqual(wrapped.text, "Hello **world**")
    XCTAssertEqual(wrapped.selection, NSRange(location: 8, length: 5))
    XCTAssertTrue(MarkdownEditorOperation.activeStyles(in: wrapped.text, selection: wrapped.selection).contains(.bold))

    let unwrapped = MarkdownEditorOperation.toggle(.bold, in: wrapped.text, selection: wrapped.selection)

    XCTAssertEqual(unwrapped.text, text)
    XCTAssertEqual(unwrapped.selection, selection)
  }

  func testBoldToggleWithoutSelectionWrapsCurrentWord() {
    let text = "Hello world"
    let cursorInsideWord = NSRange(location: 8, length: 0)

    let result = MarkdownEditorOperation.toggle(.bold, in: text, selection: cursorInsideWord)

    XCTAssertEqual(result.text, "Hello **world**")
    XCTAssertEqual(result.selection, NSRange(location: 8, length: 5))
  }

  func testBoldToggleWithoutSelectionAtEndOfWordWrapsPreviousWord() {
    let text = "Hello world"
    let cursorAtEndOfWord = NSRange(location: 11, length: 0)

    let result = MarkdownEditorOperation.toggle(.bold, in: text, selection: cursorAtEndOfWord)

    XCTAssertEqual(result.text, "Hello **world**")
    XCTAssertEqual(result.selection, NSRange(location: 8, length: 5))
  }

  func testBoldToggleWithoutSelectionInsideBoldTextUnwrapsWholeStyledSpan() {
    let text = "Hello **world**"
    let cursorInsideBoldWord = NSRange(location: 10, length: 0)

    let result = MarkdownEditorOperation.toggle(.bold, in: text, selection: cursorInsideBoldWord)

    XCTAssertEqual(result.text, "Hello world")
    XCTAssertEqual(result.selection, NSRange(location: 6, length: 5))
  }

  func testItalicToggleWithoutSelectionWrapsCurrentWord() {
    let text = "Hello world"
    let cursorInsideWord = NSRange(location: 8, length: 0)

    let result = MarkdownEditorOperation.toggle(.italic, in: text, selection: cursorInsideWord)

    XCTAssertEqual(result.text, "Hello *world*")
    XCTAssertEqual(result.selection, NSRange(location: 7, length: 5))
  }

  func testInlineCodeToggleWithoutSelectionWrapsCurrentWord() {
    let text = "Use value here"
    let cursorInsideWord = NSRange(location: 5, length: 0)

    let result = MarkdownEditorOperation.toggle(.inlineCode, in: text, selection: cursorInsideWord)

    XCTAssertEqual(result.text, "Use `value` here")
    XCTAssertEqual(result.selection, NSRange(location: 5, length: 5))
  }

  func testLinkToggleWrapsSelectionAndSelectsURL() {
    let text = "Read docs"
    let selection = NSRange(location: 5, length: 4)

    let linked = MarkdownEditorOperation.toggle(.link, in: text, selection: selection)

    XCTAssertEqual(linked.text, "Read [docs](https://example.com)")
    XCTAssertEqual((linked.text as NSString).substring(with: linked.selection), "https://example.com")
    XCTAssertTrue(MarkdownEditorOperation.activeStyles(in: linked.text, selection: NSRange(location: 6, length: 4)).contains(.link))
  }

  func testLinkToggleWithoutSelectionWrapsCurrentWordAndSelectsURL() {
    let text = "Read docs"
    let cursorInsideWord = NSRange(location: 7, length: 0)

    let linked = MarkdownEditorOperation.toggle(.link, in: text, selection: cursorInsideWord)

    XCTAssertEqual(linked.text, "Read [docs](https://example.com)")
    XCTAssertEqual((linked.text as NSString).substring(with: linked.selection), "https://example.com")
  }

  func testLinkToggleUnwrapsFullySelectedLink() {
    let text = "Read [docs](https://example.com)"
    let linkRange = NSRange(location: 5, length: 27)

    let result = MarkdownEditorOperation.toggle(.link, in: text, selection: linkRange)

    XCTAssertEqual(result.text, "Read docs")
    XCTAssertEqual(result.selection, NSRange(location: 5, length: 4))
  }

  func testCodeBlockInsertionAddsBlockSpacingAndSelectsCode() {
    let text = "# Demo"
    let selection = NSRange(location: (text as NSString).length, length: 0)

    let result = MarkdownEditorOperation.insert(.codeBlock, into: text, selection: selection, codexBlockNumber: 1)

    XCTAssertEqual(
      result.text,
      """
      # Demo

      ```swift
      let value = "Hello"
      ```
      """
    )
    XCTAssertEqual((result.text as NSString).substring(with: result.selection), "let value = \"Hello\"")
  }

  func testCodexSessionInsertionSelectsTitlePlaceholder() {
    let text = "# Demo"
    let selection = NSRange(location: (text as NSString).length, length: 0)

    let result = MarkdownEditorOperation.insert(.codexSession, into: text, selection: selection, codexBlockNumber: 3)

    XCTAssertTrue(result.text.contains("```codex id=demo-3"))
    XCTAssertEqual((result.text as NSString).substring(with: result.selection), "Describe the goal for this prompt")
  }

  func testDividerInsertionUsesSupportedHorizontalRuleSyntax() {
    let result = MarkdownEditorOperation.insert(
      .horizontalRule,
      into: "# Demo",
      selection: NSRange(location: 6, length: 0),
      codexBlockNumber: 1
    )

    XCTAssertTrue(result.text.contains("\n\n***"))
    XCTAssertFalse(result.text.contains("\n\n---"))
  }
}
