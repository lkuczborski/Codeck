extension SyntaxHighlighter {
  static let cssDefinition = LanguageDefinition(
    family: .css,
    keywords: [
      "after", "before", "calc", "currentColor", "flex", "grid", "hover", "important", "inherit", "initial",
      "none", "not", "root", "var"
    ],
    types: [],
    literals: [],
    lineComments: [],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: false,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: false
  )
}
