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
    code.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { index, line in
      let rawLine = String(line)
      let rendered: String
      if rawLine.hasPrefix("#") {
        rendered = span("syntax-section", rawLine)
      } else if rawLine.hasPrefix(">") {
        rendered = span("syntax-comment", rawLine)
      } else if rawLine.hasPrefix("- ") || rawLine.hasPrefix("* ") || rawLine.hasPrefix("+ ") {
        rendered = span("syntax-punctuation", String(rawLine.prefix(2))) + escapeHTML(String(rawLine.dropFirst(2)))
      } else {
        rendered = escapeHTML(rawLine)
      }
      return index == 0 ? rendered : "\n" + rendered
    }.joined()
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

  private static func escapeHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

  private static let operatorCharacters = Set("+-*/%=!<>|&^~?:")
  private static let punctuationCharacters = Set("()[]{}.,;")
}
