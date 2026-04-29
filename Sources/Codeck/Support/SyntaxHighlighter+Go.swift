extension SyntaxHighlighter {
  static let goDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func",
      "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct",
      "switch", "type", "var"
    ],
    types: ["bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int", "int32", "int64", "rune", "string"],
    literals: ["false", "iota", "nil", "true"],
    lineComments: ["//"],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: true,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: true
  )
}
