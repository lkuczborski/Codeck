import XCTest
@testable import Codeck

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
}
