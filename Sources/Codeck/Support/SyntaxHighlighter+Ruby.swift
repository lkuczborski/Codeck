extension SyntaxHighlighter {
  static let rubyDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "BEGIN", "END", "alias", "and", "begin", "break", "case", "class", "def", "defined", "do", "else", "elsif",
      "end", "ensure", "false", "for", "if", "in", "module", "next", "nil", "not", "or", "redo", "rescue",
      "retry", "return", "self", "super", "then", "true", "undef", "unless", "until", "when", "while", "yield"
    ],
    types: ["Array", "Hash", "Integer", "Object", "String", "Symbol"],
    literals: ["false", "nil", "true"],
    lineComments: ["#"],
    blockComments: [],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: true,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: true
  )
}
