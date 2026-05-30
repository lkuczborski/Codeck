import AppKit
import XCTest
@testable import Codeck

@MainActor
final class MarkdownEditorHighlighterTests: XCTestCase {
  func testAppliesBoldItalicInlineCodeAndStrikethroughAttributes() {
    let text = "A **bold** and *italic* word with `code` plus ~~gone~~."
    let storage = NSTextStorage(string: text)

    MarkdownEditorHighlighter.apply(to: storage, source: text)

    XCTAssertTrue(fontTraits(at: "bold", in: text, storage: storage).contains(.boldFontMask))
    XCTAssertEqual(
      storage.attribute(.foregroundColor, at: location(of: "bold", in: text), effectiveRange: nil) as? NSColor,
      NSColor.labelColor
    )
    XCTAssertTrue(fontTraits(at: "italic", in: text, storage: storage).contains(.italicFontMask))
    XCTAssertNotNil(storage.attribute(.backgroundColor, at: location(of: "code", in: text), effectiveRange: nil))
    XCTAssertEqual(
      storage.attribute(.strikethroughStyle, at: location(of: "gone", in: text), effectiveRange: nil) as? Int,
      NSUnderlineStyle.single.rawValue
    )
  }

  func testAppliesMarkdownStructureAndLinkAttributes() {
    let text = "# Title\n- [Docs](https://example.com)\n> Quote"
    let storage = NSTextStorage(string: text)

    MarkdownEditorHighlighter.apply(to: storage, source: text)

    XCTAssertEqual(
      storage.attribute(.foregroundColor, at: location(of: "Title", in: text), effectiveRange: nil) as? NSColor,
      NSColor.controlAccentColor
    )
    XCTAssertEqual(
      storage.attribute(.underlineStyle, at: location(of: "Docs", in: text), effectiveRange: nil) as? Int,
      NSUnderlineStyle.single.rawValue
    )
    XCTAssertEqual(
      storage.attribute(.foregroundColor, at: location(of: "Quote", in: text), effectiveRange: nil) as? NSColor,
      NSColor.secondaryLabelColor
    )
    XCTAssertNil(storage.attribute(.underlineStyle, at: location(of: "https://example.com", in: text), effectiveRange: nil))
  }

  func testBareURLsStayVisuallyPlain() {
    let text = "Source: https://openai.com/index/introducing-gpt-5-5/"
    let storage = NSTextStorage(string: text)

    MarkdownEditorHighlighter.apply(to: storage, source: text)

    let urlLocation = location(of: "https://openai.com", in: text)
    XCTAssertEqual(
      storage.attribute(.foregroundColor, at: urlLocation, effectiveRange: nil) as? NSColor,
      NSColor.labelColor
    )
    XCTAssertNil(storage.attribute(.underlineStyle, at: urlLocation, effectiveRange: nil))
    XCTAssertNil(storage.attribute(.link, at: urlLocation, effectiveRange: nil))
  }

  private func fontTraits(at needle: String, in text: String, storage: NSTextStorage) -> NSFontTraitMask {
    let font = storage.attribute(.font, at: location(of: needle, in: text), effectiveRange: nil) as? NSFont
    return NSFontManager.shared.traits(of: font ?? MarkdownEditorHighlighter.baseFont)
  }

  private func location(of needle: String, in text: String) -> Int {
    let range = (text as NSString).range(of: needle)
    XCTAssertNotEqual(range.location, NSNotFound)
    return range.location
  }
}
