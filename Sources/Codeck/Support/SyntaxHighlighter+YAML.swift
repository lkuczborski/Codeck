extension SyntaxHighlighter {
  static let yamlDefinition = LanguageDefinition(
    family: .yaml,
    keywords: [],
    types: [],
    literals: ["false", "no", "null", "off", "on", "true", "yes"],
    lineComments: ["#"],
    blockComments: [],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: false,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: false
  )
}
