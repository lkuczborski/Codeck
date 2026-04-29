extension SyntaxHighlighter {
  static let jsonDefinition = LanguageDefinition(
    family: .json,
    keywords: [],
    types: [],
    literals: ["false", "null", "true"],
    lineComments: [],
    blockComments: [],
    stringDelimiters: ["\""],
    supportsBacktickStrings: false,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: false
  )
}
