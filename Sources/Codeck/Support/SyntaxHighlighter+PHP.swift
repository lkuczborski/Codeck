extension SyntaxHighlighter {
  static let phpDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "abstract", "and", "array", "as", "break", "case", "catch", "class", "clone", "const", "continue", "declare",
      "default", "do", "echo", "else", "elseif", "empty", "extends", "final", "finally", "for", "foreach", "function",
      "global", "if", "implements", "include", "instanceof", "interface", "namespace", "new", "or", "private",
      "protected", "public", "require", "return", "static", "switch", "throw", "trait", "try", "use", "var", "while"
    ],
    types: ["array", "bool", "float", "int", "object", "string"],
    literals: ["false", "null", "true"],
    lineComments: ["//", "#"],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: true,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: true
  )
}
