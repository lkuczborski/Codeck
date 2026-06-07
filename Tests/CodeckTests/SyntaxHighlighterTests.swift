@testable import Codeck
import XCTest

final class SyntaxHighlighterTests: XCTestCase {
  func testLanguageIdentifierNormalizesAliasesAndFencedAttributeSyntax() {
    XCTAssertEqual(SyntaxHighlighter.languageIdentifier(from: "js"), "javascript")
    XCTAssertEqual(SyntaxHighlighter.languageIdentifier(from: "c++"), "cpp")
    XCTAssertEqual(SyntaxHighlighter.languageIdentifier(from: "{.swift title=\"Demo\"}"), "swift")
    XCTAssertEqual(SyntaxHighlighter.languageIdentifier(from: "{language-python linenos=true}"), "python")
    XCTAssertEqual(SyntaxHighlighter.languageIdentifier(from: "lang-yml"), "yaml")
  }

  func testLanguageIdentifierRejectsEmptyInfoStrings() {
    XCTAssertNil(SyntaxHighlighter.languageIdentifier(from: "   "))
    XCTAssertNil(SyntaxHighlighter.languageIdentifier(from: "{.}"))
  }

  func testPlainTextHighlightingEscapesHTMLWithoutAddingSyntaxSpans() {
    let html = SyntaxHighlighter.html(for: "<script>alert(\"x\")</script>", language: "plaintext")

    XCTAssertEqual(html, "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;")
    XCTAssertFalse(html.contains("syntax-"))
  }

  func testMarkdownHighlightingStylesInlineFormatting() {
    let html = SyntaxHighlighter.html(
      for: "# Title\nA ***bold italic***, **bold**, and *italic* [link](https://example.com) with `code`.",
      language: "markdown"
    )

    XCTAssertTrue(html.contains("<span class=\"syntax-section\">Title</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-strong-emphasis\">bold italic</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-strong\">bold</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-emphasis\">italic</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-link\">link</span>"))
    XCTAssertTrue(html.contains("](</span>https://example.com<span class=\"syntax-punctuation\">)</span>"))
    XCTAssertFalse(html.contains("<span class=\"syntax-string\">https://example.com</span>"))
    XCTAssertTrue(html.contains("<span class=\"syntax-inline-code\">code</span>"))
  }

  func testMarkdownHighlightingLeavesBareURLsPlain() {
    let html = SyntaxHighlighter.html(
      for: "Source: https://openai.com/index/introducing-gpt-5-5/",
      language: "markdown"
    )

    XCTAssertEqual(html, "Source: https://openai.com/index/introducing-gpt-5-5/")
  }
}
