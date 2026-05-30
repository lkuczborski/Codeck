import Foundation

enum SyntaxHighlighter {
  enum HighlightFamily {
    case code
    case css
    case diff
    case json
    case markup
    case markdown
    case yaml
  }

  struct LanguageDefinition {
    var family: HighlightFamily
    var keywords: Set<String>
    var types: Set<String>
    var literals: Set<String>
    var lineComments: [String]
    var blockComments: [(start: String, end: String)]
    var stringDelimiters: Set<Character>
    var supportsBacktickStrings: Bool
    var supportsBacktickIdentifiers: Bool
    var highlightsUppercaseIdentifiersAsTypes: Bool
  }

  static func languageIdentifier(from info: String) -> String? {
    guard let token = languageToken(from: info) else { return nil }
    let lowercased = token.lowercased()
    let normalized = aliases[lowercased] ?? lowercased
    let allowed = normalized.unicodeScalars.filter { scalar in
      CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
    }

    let identifier = String(String.UnicodeScalarView(allowed))
    return identifier.isEmpty ? nil : identifier
  }

  static func html(for code: String, language: String?) -> String {
    guard let language,
          !plainTextLanguages.contains(language) else {
      return escapeHTML(code)
    }

    let definition = definition(for: language) ?? genericDefinition
    switch definition.family {
    case .code:
      return highlightCode(code, definition: definition)
    case .css:
      return highlightCSS(code, definition: definition)
    case .diff:
      return highlightDiff(code)
    case .json:
      return highlightJSON(code)
    case .markup:
      return highlightMarkup(code)
    case .markdown:
      return highlightMarkdown(code)
    case .yaml:
      return highlightYAML(code, definition: definition)
    }
  }

  private static func languageToken(from info: String) -> String? {
    let trimmed = info.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
      let contents = trimmed.dropFirst().dropLast()
      for token in contents.split(whereSeparator: \.isWhitespace) {
        let value = String(token)
        if value.hasPrefix(".") {
          return cleanLanguageToken(String(value.dropFirst()))
        }
        if value.hasPrefix("language-") {
          return cleanLanguageToken(String(value.dropFirst("language-".count)))
        }
        if value.hasPrefix("lang-") {
          return cleanLanguageToken(String(value.dropFirst("lang-".count)))
        }
      }
    }

    guard let first = trimmed.split(whereSeparator: \.isWhitespace).first else {
      return nil
    }
    return cleanLanguageToken(String(first))
  }

  private static func cleanLanguageToken(_ token: String) -> String? {
    var value = token.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("language-") {
      value = String(value.dropFirst("language-".count))
    } else if value.hasPrefix("lang-") {
      value = String(value.dropFirst("lang-".count))
    }
    value = value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    return value.isEmpty ? nil : value
  }

  private static func highlightCode(_ code: String, definition: LanguageDefinition) -> String {
    var html = ""
    var index = code.startIndex

    while index < code.endIndex {
      if let comment = consumeComment(in: code, at: index, definition: definition) {
        html += span("syntax-comment", comment.text)
        index = comment.nextIndex
        continue
      }

      if let string = consumeString(in: code, at: index, definition: definition) {
        let style = string.isIdentifier ? "syntax-symbol" : "syntax-string"
        html += span(style, string.text)
        index = string.nextIndex
        continue
      }

      if let attribute = consumePrefixedIdentifier(in: code, at: index, prefix: "@") {
        html += span("syntax-attribute", attribute.text)
        index = attribute.nextIndex
        continue
      }

      if let variable = consumeShellVariable(in: code, at: index, definition: definition) {
        html += span("syntax-variable", variable.text)
        index = variable.nextIndex
        continue
      }

      if let number = consumeNumber(in: code, at: index) {
        html += span("syntax-number", number.text)
        index = number.nextIndex
        continue
      }

      if let identifier = consumeIdentifier(in: code, at: index) {
        html += highlightedIdentifier(identifier.text, in: code, start: index, end: identifier.nextIndex, definition: definition)
        index = identifier.nextIndex
        continue
      }

      let character = code[index]
      if operatorCharacters.contains(character) {
        html += span("syntax-operator", String(character))
      } else if punctuationCharacters.contains(character) {
        html += span("syntax-punctuation", String(character))
      } else {
        html += escapeHTML(String(character))
      }
      index = code.index(after: index)
    }

    return html
  }

  private static func highlightJSON(_ code: String) -> String {
    var html = ""
    var index = code.startIndex

    while index < code.endIndex {
      if let string = consumeString(in: code, at: index, definition: jsonDefinition) {
        let next = nextNonWhitespaceIndex(after: string.nextIndex, in: code)
        let style = next.map { code[$0] == ":" } == true ? "syntax-property" : "syntax-string"
        html += span(style, string.text)
        index = string.nextIndex
        continue
      }

      if let number = consumeNumber(in: code, at: index) {
        html += span("syntax-number", number.text)
        index = number.nextIndex
        continue
      }

      if let identifier = consumeIdentifier(in: code, at: index), jsonDefinition.literals.contains(identifier.text) {
        html += span("syntax-literal", identifier.text)
        index = identifier.nextIndex
        continue
      }

      let character = code[index]
      if punctuationCharacters.contains(character) || character == ":" || character == "," {
        html += span("syntax-punctuation", String(character))
      } else {
        html += escapeHTML(String(character))
      }
      index = code.index(after: index)
    }

    return html
  }

  private static func highlightYAML(_ code: String, definition: LanguageDefinition) -> String {
    var html = ""
    var lineStart = true
    var index = code.startIndex

    while index < code.endIndex {
      if lineStart, let key = consumeYAMLKey(in: code, at: index) {
        html += escapeHTML(key.indent)
        html += span("syntax-property", key.text)
        html += span("syntax-punctuation", key.separator)
        index = key.nextIndex
        lineStart = false
        continue
      }

      if let comment = consumeComment(in: code, at: index, definition: definition) {
        html += span("syntax-comment", comment.text)
        index = comment.nextIndex
        continue
      }

      if let string = consumeString(in: code, at: index, definition: definition) {
        html += span("syntax-string", string.text)
        index = string.nextIndex
        continue
      }

      if let number = consumeNumber(in: code, at: index) {
        html += span("syntax-number", number.text)
        index = number.nextIndex
        continue
      }

      if let identifier = consumeIdentifier(in: code, at: index), definition.literals.contains(identifier.text.lowercased()) {
        html += span("syntax-literal", identifier.text)
        index = identifier.nextIndex
        continue
      }

      let character = code[index]
      lineStart = character == "\n"
      html += escapeHTML(String(character))
      index = code.index(after: index)
    }

    return html
  }

  private static func highlightMarkup(_ code: String) -> String {
    var html = ""
    var index = code.startIndex

    while index < code.endIndex {
      if code[index...].hasPrefix("<!--") {
        let end = code.range(of: "-->", range: index..<code.endIndex)?.upperBound ?? code.endIndex
        html += span("syntax-comment", String(code[index..<end]))
        index = end
        continue
      }

      if code[index] == "<" {
        let end = code[index...].firstIndex(of: ">").map { code.index(after: $0) } ?? code.endIndex
        html += highlightMarkupTag(String(code[index..<end]))
        index = end
        continue
      }

      html += escapeHTML(String(code[index]))
      index = code.index(after: index)
    }

    return html
  }

  private static func highlightMarkupTag(_ tag: String) -> String {
    var html = ""
    var index = tag.startIndex
    var expectsTagName = true

    while index < tag.endIndex {
      let character = tag[index]

      if character == "<" || character == ">" || character == "/" || character == "=" {
        html += span("syntax-punctuation", String(character))
        if character == "<" || character == "/" {
          expectsTagName = true
        }
        index = tag.index(after: index)
        continue
      }

      if character == "\"" || character == "'" {
        let string = consumeQuotedText(in: tag, at: index, delimiter: character)
        html += span("syntax-string", string.text)
        index = string.nextIndex
        continue
      }

      if let identifier = consumeIdentifier(in: tag, at: index) {
        let style = expectsTagName ? "syntax-tag" : "syntax-property"
        html += span(style, identifier.text)
        expectsTagName = false
        index = identifier.nextIndex
        continue
      }

      html += escapeHTML(String(character))
      index = tag.index(after: index)
    }

    return html
  }

  private static func highlightCSS(_ code: String, definition: LanguageDefinition) -> String {
    var html = ""
    var index = code.startIndex

    while index < code.endIndex {
      if let comment = consumeComment(in: code, at: index, definition: definition) {
        html += span("syntax-comment", comment.text)
        index = comment.nextIndex
        continue
      }

      if let string = consumeString(in: code, at: index, definition: definition) {
        html += span("syntax-string", string.text)
        index = string.nextIndex
        continue
      }

      if let number = consumeNumber(in: code, at: index) {
        html += span("syntax-number", number.text)
        index = number.nextIndex
        continue
      }

      if let identifier = consumeCSSIdentifier(in: code, at: index) {
        let next = nextNonWhitespaceIndex(after: identifier.nextIndex, in: code)
        let style: String
        if definition.keywords.contains(identifier.text.lowercased()) {
          style = "syntax-keyword"
        } else if next.map({ code[$0] == ":" }) == true {
          style = "syntax-property"
        } else if next.map({ code[$0] == "(" }) == true {
          style = "syntax-function"
        } else {
          style = "syntax-name"
        }
        html += span(style, identifier.text)
        index = identifier.nextIndex
        continue
      }

      let character = code[index]
      if operatorCharacters.contains(character) {
        html += span("syntax-operator", String(character))
      } else if punctuationCharacters.contains(character) || character == ":" || character == ";" || character == "." || character == "#" {
        html += span("syntax-punctuation", String(character))
      } else {
        html += escapeHTML(String(character))
      }
      index = code.index(after: index)
    }

    return html
  }

  private static func highlightMarkdown(_ code: String) -> String {
    var isInsideFence = false

    return code.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { index, line in
      let rawLine = String(line)
      let rendered: String

      if markdownFenceMarker(in: rawLine) != nil {
        rendered = span("syntax-punctuation", rawLine)
        isInsideFence.toggle()
      } else if isInsideFence {
        rendered = escapeHTML(rawLine)
      } else if let heading = markdownHeading(in: rawLine) {
        rendered = span("syntax-punctuation", heading.marker) + spanHTML("syntax-section", highlightMarkdownInline(heading.text))
      } else if let reference = markdownReferenceDefinition(in: rawLine) {
        rendered = span("syntax-punctuation", reference.marker) + highlightMarkdownInline(reference.rest)
      } else if rawLine.hasPrefix(">") {
        rendered = span("syntax-punctuation", String(rawLine.prefix(1))) + spanHTML("syntax-comment", highlightMarkdownInline(String(rawLine.dropFirst(1))))
      } else if let markerLength = markdownListMarkerLength(in: rawLine) {
        rendered = span("syntax-punctuation", String(rawLine.prefix(markerLength))) + highlightMarkdownListContent(String(rawLine.dropFirst(markerLength)))
      } else if markdownHorizontalRule(in: rawLine) {
        rendered = span("syntax-section", rawLine)
      } else {
        rendered = highlightMarkdownInline(rawLine)
      }
      return index == 0 ? rendered : "\n" + rendered
    }.joined()
  }

  private static func highlightMarkdownInline(_ text: String) -> String {
    var html = ""
    var index = text.startIndex

    while index < text.endIndex {
      if let inlineCode = markdownDelimitedSpan(in: text, at: index, delimiter: "`", className: "syntax-inline-code", recurse: false) {
        html += inlineCode.html
        index = inlineCode.nextIndex
        continue
      }

      if let link = markdownLinkSpan(in: text, at: index) {
        html += link.html
        index = link.nextIndex
        continue
      }

      if let referenceLink = markdownReferenceLinkSpan(in: text, at: index) {
        html += referenceLink.html
        index = referenceLink.nextIndex
        continue
      }

      if let autolink = markdownAutolinkSpan(in: text, at: index) {
        html += autolink.html
        index = autolink.nextIndex
        continue
      }

      if let htmlTag = markdownHTMLSpan(in: text, at: index) {
        html += htmlTag.html
        index = htmlTag.nextIndex
        continue
      }

      if let bareURL = markdownBareURLSpan(in: text, at: index) {
        html += bareURL.html
        index = bareURL.nextIndex
        continue
      }

      if let strongEmphasis = markdownDelimitedSpan(in: text, at: index, delimiter: "***", className: "syntax-strong-emphasis") {
        html += strongEmphasis.html
        index = strongEmphasis.nextIndex
        continue
      }

      if let strongEmphasis = markdownDelimitedSpan(in: text, at: index, delimiter: "___", className: "syntax-strong-emphasis") {
        html += strongEmphasis.html
        index = strongEmphasis.nextIndex
        continue
      }

      if let strike = markdownDelimitedSpan(in: text, at: index, delimiter: "~~", className: "syntax-deletion") {
        html += strike.html
        index = strike.nextIndex
        continue
      }

      if let strong = markdownDelimitedSpan(in: text, at: index, delimiter: "**", className: "syntax-strong") {
        html += strong.html
        index = strong.nextIndex
        continue
      }

      if let strong = markdownDelimitedSpan(in: text, at: index, delimiter: "__", className: "syntax-strong") {
        html += strong.html
        index = strong.nextIndex
        continue
      }

      if let emphasis = markdownDelimitedSpan(in: text, at: index, delimiter: "*", className: "syntax-emphasis") {
        html += emphasis.html
        index = emphasis.nextIndex
        continue
      }

      if let emphasis = markdownDelimitedSpan(in: text, at: index, delimiter: "_", className: "syntax-emphasis") {
        html += emphasis.html
        index = emphasis.nextIndex
        continue
      }

      html += escapeHTML(String(text[index]))
      index = text.index(after: index)
    }

    return html
  }

  private static func highlightMarkdownListContent(_ text: String) -> String {
    if text.hasPrefix("[ ] ") || text.hasPrefix("[x] ") || text.hasPrefix("[X] ") {
      return span("syntax-punctuation", String(text.prefix(3))) + highlightMarkdownInline(String(text.dropFirst(3)))
    }

    return highlightMarkdownInline(text)
  }

  private static func markdownDelimitedSpan(
    in text: String,
    at index: String.Index,
    delimiter: String,
    className: String,
    recurse: Bool = true
  ) -> (html: String, nextIndex: String.Index)? {
    guard text[index...].hasPrefix(delimiter) else { return nil }

    let contentStart = text.index(index, offsetBy: delimiter.count)
    guard contentStart < text.endIndex,
          let closingRange = text.range(of: delimiter, range: contentStart..<text.endIndex),
          closingRange.lowerBound > contentStart else {
      return nil
    }

    let content = String(text[contentStart..<closingRange.lowerBound])
    let renderedContent = recurse ? highlightMarkdownInline(content) : escapeHTML(content)
    let html = span("syntax-punctuation", delimiter)
      + spanHTML(className, renderedContent)
      + span("syntax-punctuation", delimiter)
    return (html, closingRange.upperBound)
  }

  private static func markdownLinkSpan(in text: String, at index: String.Index) -> (html: String, nextIndex: String.Index)? {
    var cursor = index
    var imagePrefix = ""

    if text[cursor] == "!" {
      let next = text.index(after: cursor)
      guard next < text.endIndex, text[next] == "[" else { return nil }
      imagePrefix = "!"
      cursor = next
    }

    guard text[cursor] == "[" else { return nil }
    let titleStart = text.index(after: cursor)
    guard let titleEnd = text[titleStart...].firstIndex(of: "]") else { return nil }
    let parenStart = text.index(after: titleEnd)
    guard parenStart < text.endIndex, text[parenStart] == "(" else { return nil }

    let urlStart = text.index(after: parenStart)
    guard let urlEnd = text[urlStart...].firstIndex(of: ")") else { return nil }

    let title = String(text[titleStart..<titleEnd])
    let url = String(text[urlStart..<urlEnd])
    let html = span("syntax-punctuation", imagePrefix + "[")
      + spanHTML("syntax-link", highlightMarkdownInline(title))
      + span("syntax-punctuation", "](")
      + escapeHTML(url)
      + span("syntax-punctuation", ")")
    return (html, text.index(after: urlEnd))
  }

  private static func markdownReferenceLinkSpan(in text: String, at index: String.Index) -> (html: String, nextIndex: String.Index)? {
    var cursor = index
    var imagePrefix = ""

    if text[cursor] == "!" {
      let next = text.index(after: cursor)
      guard next < text.endIndex, text[next] == "[" else { return nil }
      imagePrefix = "!"
      cursor = next
    }

    guard text[cursor] == "[" else { return nil }
    let titleStart = text.index(after: cursor)
    guard let titleEnd = text[titleStart...].firstIndex(of: "]") else { return nil }
    let labelOpen = text.index(after: titleEnd)
    guard labelOpen < text.endIndex, text[labelOpen] == "[" else { return nil }
    let labelStart = text.index(after: labelOpen)
    guard let labelEnd = text[labelStart...].firstIndex(of: "]") else { return nil }

    let title = String(text[titleStart..<titleEnd])
    let label = String(text[labelStart..<labelEnd])
    let html = span("syntax-punctuation", imagePrefix + "[")
      + spanHTML("syntax-link", highlightMarkdownInline(title))
      + span("syntax-punctuation", "][")
      + escapeHTML(label)
      + span("syntax-punctuation", "]")
    return (html, text.index(after: labelEnd))
  }

  private static func markdownAutolinkSpan(in text: String, at index: String.Index) -> (html: String, nextIndex: String.Index)? {
    guard text[index] == "<",
          let closing = text[text.index(after: index)...].firstIndex(of: ">") else {
      return nil
    }

    let valueStart = text.index(after: index)
    let value = String(text[valueStart..<closing])
    guard isMarkdownAutolinkValue(value) else { return nil }

    let html = span("syntax-punctuation", "<")
      + escapeHTML(value)
      + span("syntax-punctuation", ">")
    return (html, text.index(after: closing))
  }

  private static func markdownHTMLSpan(in text: String, at index: String.Index) -> (html: String, nextIndex: String.Index)? {
    guard text[index] == "<" else { return nil }
    let next = text.index(after: index)
    guard next < text.endIndex,
          text[next].isLetter || text[next] == "/" || text[next] == "!" || text[next] == "?" else {
      return nil
    }
    guard let closing = text[next...].firstIndex(of: ">") else { return nil }
    let end = text.index(after: closing)
    return (span("syntax-tag", String(text[index..<end])), end)
  }

  private static func markdownBareURLSpan(in text: String, at index: String.Index) -> (html: String, nextIndex: String.Index)? {
    guard let prefix = markdownBareURLPrefix(in: text, at: index) else { return nil }
    var cursor = text.index(index, offsetBy: prefix.count)

    while cursor < text.endIndex, !text[cursor].isWhitespace, !bareURLTerminators.contains(text[cursor]) {
      cursor = text.index(after: cursor)
    }

    while cursor > index {
      let previous = text.index(before: cursor)
      guard trailingURLPunctuation.contains(text[previous]) else { break }
      cursor = previous
    }

    guard cursor > index else { return nil }
    return (escapeHTML(String(text[index..<cursor])), cursor)
  }

  private static func markdownHeading(in line: String) -> (marker: String, text: String)? {
    let marker = line.prefix(while: { $0 == "#" })
    guard (1...6).contains(marker.count) else { return nil }

    let markerEnd = line.index(line.startIndex, offsetBy: marker.count)
    guard markerEnd < line.endIndex, line[markerEnd] == " " else { return nil }
    return (String(line[..<line.index(after: markerEnd)]), String(line[line.index(after: markerEnd)...]))
  }

  private static func markdownReferenceDefinition(in line: String) -> (marker: String, rest: String)? {
    let leadingSpaces = line.prefix(while: { $0 == " " }).count
    guard leadingSpaces <= 3 else { return nil }

    let start = line.index(line.startIndex, offsetBy: leadingSpaces)
    guard start < line.endIndex, line[start] == "[" else { return nil }
    guard let closing = line[start...].firstIndex(of: "]") else { return nil }
    let colon = line.index(after: closing)
    guard colon < line.endIndex, line[colon] == ":" else { return nil }

    let markerEnd = line.index(after: colon)
    return (String(line[line.startIndex..<markerEnd]), String(line[markerEnd...]))
  }

  private static func markdownFenceMarker(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") else { return nil }
    return String(trimmed.prefix(3))
  }

  private static func markdownHorizontalRule(in line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.count >= 3 else { return false }
    return trimmed.allSatisfy { $0 == "*" } || trimmed.allSatisfy { $0 == "_" } || trimmed.allSatisfy { $0 == "-" }
  }

  private static func markdownListMarkerLength(in line: String) -> Int? {
    if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
      return 2
    }

    var digitCount = 0
    for character in line {
      if character.isNumber {
        digitCount += 1
        continue
      }
      if character == ".", digitCount > 0 {
        let nextIndex = line.index(line.startIndex, offsetBy: digitCount + 1)
        if nextIndex < line.endIndex, line[nextIndex] == " " {
          return digitCount + 2
        }
      }
      return nil
    }

    return nil
  }

  private static func markdownBareURLPrefix(in text: String, at index: String.Index) -> String? {
    for prefix in ["https://", "http://", "www."] where text[index...].lowercased().hasPrefix(prefix) {
      return prefix
    }
    return nil
  }

  private static func isMarkdownAutolinkValue(_ value: String) -> Bool {
    let lowercased = value.lowercased()
    return lowercased.hasPrefix("http://")
      || lowercased.hasPrefix("https://")
      || lowercased.hasPrefix("mailto:")
      || (value.contains("@") && value.contains(".") && !value.contains(" "))
  }

  private static func highlightDiff(_ code: String) -> String {
    code.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { index, line in
      let rawLine = String(line)
      let style: String?
      if rawLine.hasPrefix("+"), !rawLine.hasPrefix("+++") {
        style = "syntax-addition"
      } else if rawLine.hasPrefix("-"), !rawLine.hasPrefix("---") {
        style = "syntax-deletion"
      } else if rawLine.hasPrefix("@@") {
        style = "syntax-section"
      } else {
        style = nil
      }

      let rendered = style.map { span($0, rawLine) } ?? escapeHTML(rawLine)
      return index == 0 ? rendered : "\n" + rendered
    }.joined()
  }

  private static func highlightedIdentifier(
    _ text: String,
    in code: String,
    start: String.Index,
    end: String.Index,
    definition: LanguageDefinition
  ) -> String {
    let lowercased = text.lowercased()
    if definition.keywords.contains(text) || definition.keywords.contains(lowercased) {
      return span("syntax-keyword", text)
    }
    if definition.literals.contains(text) || definition.literals.contains(lowercased) {
      return span("syntax-literal", text)
    }
    if definition.types.contains(text) || definition.types.contains(lowercased) {
      return span("syntax-type", text)
    }
    if definition.highlightsUppercaseIdentifiersAsTypes, text.first?.isUppercase == true {
      return span("syntax-type", text)
    }

    if previousNonWhitespaceIndex(before: start, in: code).map({ code[$0] == "." }) == true {
      return span("syntax-property", text)
    }
    if nextNonWhitespaceIndex(after: end, in: code).map({ code[$0] == "(" }) == true {
      return span("syntax-function", text)
    }
    return escapeHTML(text)
  }

  private static func consumeComment(
    in code: String,
    at index: String.Index,
    definition: LanguageDefinition
  ) -> (text: String, nextIndex: String.Index)? {
    for comment in definition.blockComments where code[index...].hasPrefix(comment.start) {
      let searchStart = code.index(index, offsetBy: comment.start.count, limitedBy: code.endIndex) ?? code.endIndex
      let end = code.range(of: comment.end, range: searchStart..<code.endIndex)?.upperBound ?? code.endIndex
      return (String(code[index..<end]), end)
    }

    for comment in definition.lineComments where code[index...].hasPrefix(comment) {
      let end = code[index...].firstIndex(of: "\n") ?? code.endIndex
      return (String(code[index..<end]), end)
    }

    return nil
  }

  private static func consumeString(
    in code: String,
    at index: String.Index,
    definition: LanguageDefinition
  ) -> (text: String, nextIndex: String.Index, isIdentifier: Bool)? {
    if definition.supportsBacktickIdentifiers, code[index] == "`" {
      let string = consumeQuotedText(in: code, at: index, delimiter: "`")
      return (string.text, string.nextIndex, true)
    }

    if code[index...].hasPrefix("\"\"\"") || code[index...].hasPrefix("'''") {
      let delimiter = String(code[index..<code.index(index, offsetBy: 3)])
      let searchStart = code.index(index, offsetBy: 3)
      let end = code.range(of: delimiter, range: searchStart..<code.endIndex)?.upperBound ?? code.endIndex
      return (String(code[index..<end]), end, false)
    }

    let character = code[index]
    if character == "`", definition.supportsBacktickStrings {
      let string = consumeQuotedText(in: code, at: index, delimiter: "`")
      return (string.text, string.nextIndex, false)
    }
    guard definition.stringDelimiters.contains(character) else { return nil }
    let string = consumeQuotedText(in: code, at: index, delimiter: character)
    return (string.text, string.nextIndex, false)
  }

  private static func consumeQuotedText(
    in code: String,
    at index: String.Index,
    delimiter: Character
  ) -> (text: String, nextIndex: String.Index) {
    var cursor = code.index(after: index)
    var escaped = false

    while cursor < code.endIndex {
      let character = code[cursor]
      if escaped {
        escaped = false
      } else if character == "\\" {
        escaped = true
      } else if character == delimiter {
        let end = code.index(after: cursor)
        return (String(code[index..<end]), end)
      }
      cursor = code.index(after: cursor)
    }

    return (String(code[index..<code.endIndex]), code.endIndex)
  }

  private static func consumePrefixedIdentifier(
    in code: String,
    at index: String.Index,
    prefix: Character
  ) -> (text: String, nextIndex: String.Index)? {
    guard code[index] == prefix else { return nil }
    let next = code.index(after: index)
    guard next < code.endIndex, isIdentifierStart(code[next]) else { return nil }
    let identifier = consumeIdentifier(in: code, at: next)
    return identifier.map { (String(prefix) + $0.text, $0.nextIndex) }
  }

  private static func consumeShellVariable(
    in code: String,
    at index: String.Index,
    definition: LanguageDefinition
  ) -> (text: String, nextIndex: String.Index)? {
    guard definition.lineComments.contains("#"), code[index] == "$" else { return nil }
    let next = code.index(after: index)
    guard next < code.endIndex else { return nil }

    if code[next] == "{" {
      let end = code[next...].firstIndex(of: "}").map { code.index(after: $0) } ?? code.index(after: next)
      return (String(code[index..<end]), end)
    }

    guard isIdentifierStart(code[next]) else { return nil }
    let identifier = consumeIdentifier(in: code, at: next)
    return identifier.map { ("$" + $0.text, $0.nextIndex) }
  }

  private static func consumeNumber(
    in code: String,
    at index: String.Index
  ) -> (text: String, nextIndex: String.Index)? {
    guard code[index].isNumber else { return nil }
    var cursor = code.index(after: index)

    while cursor < code.endIndex {
      let character = code[cursor]
      guard character.isNumber || character.isLetter || character == "." || character == "_" else {
        break
      }
      cursor = code.index(after: cursor)
    }

    return (String(code[index..<cursor]), cursor)
  }

  private static func consumeIdentifier(
    in code: String,
    at index: String.Index
  ) -> (text: String, nextIndex: String.Index)? {
    guard isIdentifierStart(code[index]) else { return nil }
    var cursor = code.index(after: index)
    while cursor < code.endIndex, isIdentifierContinuation(code[cursor]) {
      cursor = code.index(after: cursor)
    }
    return (String(code[index..<cursor]), cursor)
  }

  private static func consumeCSSIdentifier(
    in code: String,
    at index: String.Index
  ) -> (text: String, nextIndex: String.Index)? {
    guard isIdentifierStart(code[index]) || code[index] == "-" else { return nil }
    var cursor = code.index(after: index)
    while cursor < code.endIndex {
      let character = code[cursor]
      guard isIdentifierContinuation(character) || character == "-" else { break }
      cursor = code.index(after: cursor)
    }
    return (String(code[index..<cursor]), cursor)
  }

  private static func consumeYAMLKey(
    in code: String,
    at index: String.Index
  ) -> (indent: String, text: String, separator: String, nextIndex: String.Index)? {
    var cursor = index
    while cursor < code.endIndex, code[cursor] == " " || code[cursor] == "\t" {
      cursor = code.index(after: cursor)
    }
    let keyStart = cursor
    while cursor < code.endIndex {
      let character = code[cursor]
      if character == ":" || character == "=" {
        let key = String(code[keyStart..<cursor]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !key.contains(" ") else { return nil }
        let separatorIndex = cursor
        let next = code.index(after: cursor)
        return (
          indent: String(code[index..<keyStart]),
          text: String(code[keyStart..<separatorIndex]),
          separator: String(character),
          nextIndex: next
        )
      }
      if character == "\n" || character == "#" {
        return nil
      }
      cursor = code.index(after: cursor)
    }
    return nil
  }

  private static func previousNonWhitespaceIndex(before index: String.Index, in code: String) -> String.Index? {
    var cursor = index
    while cursor > code.startIndex {
      cursor = code.index(before: cursor)
      if !code[cursor].isWhitespace {
        return cursor
      }
    }
    return nil
  }

  private static func nextNonWhitespaceIndex(after index: String.Index, in code: String) -> String.Index? {
    var cursor = index
    while cursor < code.endIndex {
      if !code[cursor].isWhitespace {
        return cursor
      }
      cursor = code.index(after: cursor)
    }
    return nil
  }

  private static func isIdentifierStart(_ character: Character) -> Bool {
    character == "_" || character == "$" || character.isLetter
  }

  private static func isIdentifierContinuation(_ character: Character) -> Bool {
    isIdentifierStart(character) || character.isNumber
  }

  private static func span(_ className: String, _ text: String) -> String {
    "<span class=\"\(className)\">\(escapeHTML(text))</span>"
  }

  private static func spanHTML(_ className: String, _ html: String) -> String {
    "<span class=\"\(className)\">\(html)</span>"
  }

  private static func escapeHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

  private static let operatorCharacters = Set("+-*/%=!<>|&^~?:")
  private static let punctuationCharacters = Set("()[]{}.,;")
  private static let bareURLTerminators = Set("<>[]{}\"'")
  private static let trailingURLPunctuation = Set(".,;:!?)")
}
