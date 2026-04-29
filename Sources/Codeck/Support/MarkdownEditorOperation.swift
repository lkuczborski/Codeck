import Foundation

struct MarkdownEditResult: Equatable {
  var text: String
  var selection: NSRange
}

enum MarkdownTextStyle: String, CaseIterable, Identifiable, Hashable {
  case bold
  case italic
  case inlineCode
  case strikethrough
  case link

  var id: String { rawValue }

  var title: String {
    switch self {
    case .bold:
      "Bold"
    case .italic:
      "Italic"
    case .inlineCode:
      "Inline Code"
    case .strikethrough:
      "Strikethrough"
    case .link:
      "Link"
    }
  }

  var help: String {
    switch self {
    case .bold:
      "Bold selected text"
    case .italic:
      "Italicize selected text"
    case .inlineCode:
      "Format selected text as inline code"
    case .strikethrough:
      "Strike through selected text"
    case .link:
      "Turn selected text into a link"
    }
  }

  var marker: String? {
    switch self {
    case .bold:
      "**"
    case .italic:
      "*"
    case .inlineCode:
      "`"
    case .strikethrough:
      "~~"
    case .link:
      nil
    }
  }

  var placeholder: String {
    switch self {
    case .inlineCode:
      "code"
    case .link:
      "Link text"
    default:
      "text"
    }
  }
}

enum MarkdownInsertion: String, CaseIterable, Identifiable {
  case heading1
  case heading2
  case heading3
  case paragraph
  case bulletedList
  case numberedList
  case blockquote
  case link
  case image
  case codeBlock
  case table
  case horizontalRule
  case codexSession

  var id: String { rawValue }

  var title: String {
    switch self {
    case .heading1:
      "Heading 1"
    case .heading2:
      "Heading 2"
    case .heading3:
      "Heading 3"
    case .paragraph:
      "Paragraph"
    case .bulletedList:
      "Bulleted List"
    case .numberedList:
      "Numbered List"
    case .blockquote:
      "Quote"
    case .link:
      "Link"
    case .image:
      "Image"
    case .codeBlock:
      "Code Block"
    case .table:
      "Table"
    case .horizontalRule:
      "Divider"
    case .codexSession:
      "Codex Session"
    }
  }

  var systemImage: String {
    switch self {
    case .heading1, .heading2, .heading3:
      "textformat.size"
    case .paragraph:
      "paragraphsign"
    case .bulletedList:
      "list.bullet"
    case .numberedList:
      "list.number"
    case .blockquote:
      "quote.opening"
    case .link:
      "link"
    case .image:
      "photo"
    case .codeBlock:
      "chevron.left.forwardslash.chevron.right"
    case .table:
      "tablecells"
    case .horizontalRule:
      "minus"
    case .codexSession:
      "terminal"
    }
  }

  var isBlock: Bool {
    self != .link
  }

  func template(codexBlockNumber: Int) -> MarkdownInsertionTemplate {
    switch self {
    case .heading1:
      MarkdownInsertionTemplate(text: "# Heading", selectedText: "Heading")
    case .heading2:
      MarkdownInsertionTemplate(text: "## Heading", selectedText: "Heading")
    case .heading3:
      MarkdownInsertionTemplate(text: "### Heading", selectedText: "Heading")
    case .paragraph:
      MarkdownInsertionTemplate(text: "Paragraph text", selectedText: "Paragraph text")
    case .bulletedList:
      MarkdownInsertionTemplate(text: "- First item\n- Second item", selectedText: "First item")
    case .numberedList:
      MarkdownInsertionTemplate(text: "1. First item\n2. Second item", selectedText: "First item")
    case .blockquote:
      MarkdownInsertionTemplate(text: "> Quote text", selectedText: "Quote text")
    case .link:
      MarkdownInsertionTemplate(text: "[Link text](https://example.com)", selectedText: "Link text")
    case .image:
      MarkdownInsertionTemplate(text: "![Alt text](Images/example.png)", selectedText: "Alt text")
    case .codeBlock:
      MarkdownInsertionTemplate(text: "```swift\nlet value = \"Hello\"\n```", selectedText: "let value = \"Hello\"")
    case .table:
      MarkdownInsertionTemplate(
        text: "| Header | Header |\n| --- | --- |\n| Cell | Cell |",
        selectedText: "Header"
      )
    case .horizontalRule:
      MarkdownInsertionTemplate(text: "***", selectedText: nil)
    case .codexSession:
      MarkdownInsertionTemplate(
        text:
          """
          ```codex id=demo-\(codexBlockNumber)
          title: Describe the goal for this prompt

          Explain this concept with one concrete example.
          ```
          """,
        selectedText: "Describe the goal for this prompt"
      )
    }
  }
}

struct MarkdownInsertionTemplate {
  var text: String
  var selectedText: String?
}

enum MarkdownEditorOperation {
  static func insert(
    _ insertion: MarkdownInsertion,
    into text: String,
    selection: NSRange,
    codexBlockNumber: Int
  ) -> MarkdownEditResult {
    let source = text as NSString
    let range = clamped(selection, length: source.length)
    let template = insertion.template(codexBlockNumber: codexBlockNumber)
    let boundary: (prefix: String, suffix: String) = insertion.isBlock
      ? blockBoundary(in: source, range: range)
      : (prefix: "", suffix: "")
    let replacement = boundary.prefix + template.text + boundary.suffix
    let result = source.replacingCharacters(in: range, with: replacement)
    let templateOffset = range.location + boundary.prefix.utf16.count

    if let selectedText = template.selectedText,
       let placeholderRange = (template.text as NSString).rangeOfFirstOccurrence(of: selectedText) {
      return MarkdownEditResult(
        text: result,
        selection: NSRange(
          location: templateOffset + placeholderRange.location,
          length: placeholderRange.length
        )
      )
    }

    return MarkdownEditResult(
      text: result,
      selection: NSRange(location: templateOffset + template.text.utf16.count, length: 0)
    )
  }

  static func toggle(
    _ style: MarkdownTextStyle,
    in text: String,
    selection: NSRange
  ) -> MarkdownEditResult {
    if style == .link {
      return toggleLink(in: text, selection: selection)
    }

    guard let marker = style.marker else {
      return MarkdownEditResult(text: text, selection: selection)
    }

    let source = text as NSString
    let range = clamped(selection, length: source.length)

    if range.length == 0,
       let markedSpan = markedSpan(containingCursorAt: range.location, in: source, marker: marker) {
      let innerText = source.substring(with: markedSpan.innerRange)
      let result = source.replacingCharacters(in: markedSpan.fullRange, with: innerText)
      return MarkdownEditResult(
        text: result,
        selection: NSRange(location: markedSpan.fullRange.location, length: innerText.utf16.count)
      )
    }

    if let unwrapped = unwrapSelectionIncludingMarkers(source: source, range: range, marker: marker) {
      return unwrapped
    }

    if let unwrapped = unwrapMarkersAroundSelection(source: source, range: range, marker: marker) {
      return unwrapped
    }

    let effectiveRange = range.length > 0 ? range : wordRange(containingCursorAt: range.location, in: source) ?? range
    let selectedText = effectiveRange.length > 0 ? source.substring(with: effectiveRange) : style.placeholder
    let replacement = marker + selectedText + marker
    let result = source.replacingCharacters(in: effectiveRange, with: replacement)

    return MarkdownEditResult(
      text: result,
      selection: NSRange(location: effectiveRange.location + marker.utf16.count, length: selectedText.utf16.count)
    )
  }

  static func activeStyles(in text: String, selection: NSRange) -> Set<MarkdownTextStyle> {
    let source = text as NSString
    let range = clamped(selection, length: source.length)

    return Set(MarkdownTextStyle.allCases.filter { style in
      if style == .link {
        return linkRange(containing: range, in: source) != nil
      }

      guard let marker = style.marker else { return false }
      return selectionHasMarkers(source: source, range: range, marker: marker)
        || selectionIncludesMarkers(source: source, range: range, marker: marker)
        || cursorIsInsideMarkers(source: source, range: range, marker: marker)
    })
  }

  private static func toggleLink(in text: String, selection: NSRange) -> MarkdownEditResult {
    let source = text as NSString
    let range = clamped(selection, length: source.length)

    if let link = linkRange(containing: range, in: source) {
      let result = source.replacingCharacters(in: link.fullRange, with: link.title)
      return MarkdownEditResult(
        text: result,
        selection: NSRange(location: link.fullRange.location, length: link.title.utf16.count)
      )
    }

    let effectiveRange = range.length > 0 ? range : wordRange(containingCursorAt: range.location, in: source) ?? range
    let title = effectiveRange.length > 0 ? source.substring(with: effectiveRange) : MarkdownTextStyle.link.placeholder
    let url = "https://example.com"
    let replacement = "[\(title)](\(url))"
    let result = source.replacingCharacters(in: effectiveRange, with: replacement)
    let selectionLocation = effectiveRange.location + title.utf16.count + 3
    return MarkdownEditResult(text: result, selection: NSRange(location: selectionLocation, length: url.utf16.count))
  }

  private static func blockBoundary(in source: NSString, range: NSRange) -> (prefix: String, suffix: String) {
    let before = source.substring(to: range.location)
    let after = source.substring(from: range.location + range.length)

    let prefix: String
    if before.isEmpty || before.hasSuffix("\n\n") {
      prefix = ""
    } else if before.hasSuffix("\n") {
      prefix = "\n"
    } else {
      prefix = "\n\n"
    }

    let suffix: String
    if after.isEmpty || after.hasPrefix("\n\n") {
      suffix = ""
    } else if after.hasPrefix("\n") {
      suffix = "\n"
    } else {
      suffix = "\n\n"
    }

    return (prefix, suffix)
  }

  private static func unwrapSelectionIncludingMarkers(
    source: NSString,
    range: NSRange,
    marker: String
  ) -> MarkdownEditResult? {
    let markerLength = marker.utf16.count
    guard range.length >= markerLength * 2 else { return nil }

    let selected = source.substring(with: range)
    guard selected.hasPrefix(marker), selected.hasSuffix(marker), markerIsUnambiguous(source: source, range: range, marker: marker) else {
      return nil
    }

    let innerRange = NSRange(location: markerLength, length: range.length - markerLength * 2)
    let innerText = (selected as NSString).substring(with: innerRange)
    let result = source.replacingCharacters(in: range, with: innerText)
    return MarkdownEditResult(text: result, selection: NSRange(location: range.location, length: innerText.utf16.count))
  }

  private static func unwrapMarkersAroundSelection(
    source: NSString,
    range: NSRange,
    marker: String
  ) -> MarkdownEditResult? {
    let markerLength = marker.utf16.count
    let beforeRange = NSRange(location: range.location - markerLength, length: markerLength)
    let afterRange = NSRange(location: range.location + range.length, length: markerLength)

    guard beforeRange.location >= 0,
          NSMaxRange(afterRange) <= source.length,
          source.substring(with: beforeRange) == marker,
          source.substring(with: afterRange) == marker,
          markerIsUnambiguous(source: source, range: beforeRange, marker: marker),
          markerIsUnambiguous(source: source, range: afterRange, marker: marker) else {
      return nil
    }

    let selectedText = source.substring(with: range)
    let fullRange = NSRange(location: beforeRange.location, length: range.length + markerLength * 2)
    let result = source.replacingCharacters(in: fullRange, with: selectedText)
    return MarkdownEditResult(
      text: result,
      selection: NSRange(location: range.location - markerLength, length: range.length)
    )
  }

  private static func selectionHasMarkers(source: NSString, range: NSRange, marker: String) -> Bool {
    let markerLength = marker.utf16.count
    let beforeRange = NSRange(location: range.location - markerLength, length: markerLength)
    let afterRange = NSRange(location: range.location + range.length, length: markerLength)

    return beforeRange.location >= 0
      && NSMaxRange(afterRange) <= source.length
      && source.substring(with: beforeRange) == marker
      && source.substring(with: afterRange) == marker
      && markerIsUnambiguous(source: source, range: beforeRange, marker: marker)
      && markerIsUnambiguous(source: source, range: afterRange, marker: marker)
  }

  private static func selectionIncludesMarkers(source: NSString, range: NSRange, marker: String) -> Bool {
    let markerLength = marker.utf16.count
    guard range.length >= markerLength * 2 else { return false }
    let selected = source.substring(with: range)
    return selected.hasPrefix(marker)
      && selected.hasSuffix(marker)
      && markerIsUnambiguous(source: source, range: range, marker: marker)
  }

  private static func cursorIsInsideMarkers(source: NSString, range: NSRange, marker: String) -> Bool {
    guard range.length == 0 else { return false }
    return markedSpan(containingCursorAt: range.location, in: source, marker: marker) != nil
  }

  private static func markedSpan(
    containingCursorAt location: Int,
    in source: NSString,
    marker: String
  ) -> (fullRange: NSRange, innerRange: NSRange)? {
    guard source.length > 0 else { return nil }

    let cursorLocation = min(max(location, 0), source.length)
    let lineRange = source.lineRange(for: NSRange(location: cursorLocation, length: 0))
    var searchLocation = lineRange.location

    while searchLocation < NSMaxRange(lineRange) {
      let searchRange = NSRange(location: searchLocation, length: NSMaxRange(lineRange) - searchLocation)
      let openingRange = source.range(of: marker, options: [], range: searchRange)
      guard openingRange.location != NSNotFound else { break }

      let closingSearchLocation = NSMaxRange(openingRange)
      guard closingSearchLocation <= NSMaxRange(lineRange) else { break }

      let closingSearchRange = NSRange(
        location: closingSearchLocation,
        length: NSMaxRange(lineRange) - closingSearchLocation
      )
      let closingRange = source.range(of: marker, options: [], range: closingSearchRange)
      guard closingRange.location != NSNotFound else { break }

      let innerRange = NSRange(
        location: NSMaxRange(openingRange),
        length: closingRange.location - NSMaxRange(openingRange)
      )
      let fullRange = NSRange(
        location: openingRange.location,
        length: NSMaxRange(closingRange) - openingRange.location
      )

      if cursorLocation >= innerRange.location,
         cursorLocation <= NSMaxRange(innerRange),
         markerIsUnambiguous(source: source, range: openingRange, marker: marker),
         markerIsUnambiguous(source: source, range: closingRange, marker: marker) {
        return (fullRange, innerRange)
      }

      searchLocation = NSMaxRange(openingRange)
    }

    return nil
  }

  private static func wordRange(containingCursorAt location: Int, in source: NSString) -> NSRange? {
    guard source.length > 0 else { return nil }

    let cursorLocation = min(max(location, 0), source.length)
    let probeLocation: Int
    if cursorLocation < source.length, isWordCharacter(at: cursorLocation, in: source) {
      probeLocation = cursorLocation
    } else if cursorLocation > 0, isWordCharacter(at: cursorLocation - 1, in: source) {
      probeLocation = cursorLocation - 1
    } else {
      return nil
    }

    var lowerBound = probeLocation
    while lowerBound > 0, isWordCharacter(at: lowerBound - 1, in: source) {
      lowerBound -= 1
    }

    var upperBound = probeLocation + 1
    while upperBound < source.length, isWordCharacter(at: upperBound, in: source) {
      upperBound += 1
    }

    return NSRange(location: lowerBound, length: upperBound - lowerBound)
  }

  private static func isWordCharacter(at location: Int, in source: NSString) -> Bool {
    guard location >= 0, location < source.length else { return false }
    let character = source.substring(with: NSRange(location: location, length: 1))
    return character.rangeOfCharacter(from: wordCharacters.inverted) == nil
  }

  private static func markerIsUnambiguous(source: NSString, range: NSRange, marker: String) -> Bool {
    guard marker == "*" else { return true }

    let beforeLocation = range.location - 1
    let afterLocation = NSMaxRange(range)
    if beforeLocation >= 0, source.substring(with: NSRange(location: beforeLocation, length: 1)) == "*" {
      return false
    }
    if afterLocation < source.length, source.substring(with: NSRange(location: afterLocation, length: 1)) == "*" {
      return false
    }
    return true
  }

  private static func linkRange(containing range: NSRange, in source: NSString) -> (fullRange: NSRange, title: String)? {
    if range.length > 0 {
      let selected = source.substring(with: range) as NSString
      let titleEnd = selected.range(of: "](")
      if selected.hasPrefix("["),
         selected.hasSuffix(")"),
         titleEnd.location != NSNotFound {
        let titleRange = NSRange(location: 1, length: titleEnd.location - 1)
        if titleRange.length >= 0 {
          return (range, selected.substring(with: titleRange))
        }
      }
    }

    let searchStart = NSRange(location: 0, length: range.location)
    let openRange = source.range(of: "[", options: .backwards, range: searchStart)
    guard openRange.location != NSNotFound else { return nil }

    let afterSelection = NSRange(location: range.location + range.length, length: source.length - range.location - range.length)
    let closeRange = source.range(of: ")", options: [], range: afterSelection)
    guard closeRange.location != NSNotFound else { return nil }

    let candidateRange = NSRange(location: openRange.location, length: closeRange.location - openRange.location + 1)
    let candidate = source.substring(with: candidateRange) as NSString
    let titleEnd = candidate.range(of: "](")
    guard titleEnd.location != NSNotFound else { return nil }

    let titleRange = NSRange(location: 1, length: titleEnd.location - 1)
    guard titleRange.length >= 0 else { return nil }

    let absoluteTitleRange = NSRange(location: openRange.location + 1, length: titleRange.length)
    let selectionStart = range.location
    let selectionEnd = range.location + range.length
    let titleStart = absoluteTitleRange.location
    let titleEndLocation = NSMaxRange(absoluteTitleRange)

    guard selectionStart >= titleStart, selectionEnd <= titleEndLocation else {
      return nil
    }

    return (candidateRange, candidate.substring(with: titleRange))
  }

  private static func clamped(_ range: NSRange, length: Int) -> NSRange {
    let location = min(max(range.location, 0), length)
    let upperBound = min(max(range.location + range.length, location), length)
    return NSRange(location: location, length: upperBound - location)
  }

  private static let wordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
}

private extension NSString {
  func rangeOfFirstOccurrence(of text: String) -> NSRange? {
    let range = range(of: text)
    return range.location == NSNotFound ? nil : range
  }
}
