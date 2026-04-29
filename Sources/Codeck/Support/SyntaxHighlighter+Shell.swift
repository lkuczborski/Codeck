extension SyntaxHighlighter {
  static let shellDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "case", "do", "done", "elif", "else", "esac", "export", "fi", "for", "function", "if", "in", "local",
      "readonly", "return", "select", "set", "shift", "then", "until", "while"
    ],
    types: [],
    literals: ["false", "true"],
    lineComments: ["#"],
    blockComments: [],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: true,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: false
  )
}
