extension SyntaxHighlighter {
  static let javaDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "abstract", "as", "break", "case", "catch", "class", "const", "continue", "data", "default", "do", "else",
      "enum", "extends", "final", "finally", "for", "fun", "if", "implements", "import", "in", "interface", "new",
      "object", "override", "package", "private", "protected", "public", "return", "sealed", "static", "super",
      "switch", "this", "throw", "throws", "try", "val", "var", "void", "when", "while"
    ],
    types: ["Boolean", "Double", "Float", "Integer", "List", "Long", "Map", "String", "boolean", "double", "float", "int", "long"],
    literals: ["false", "null", "true"],
    lineComments: ["//"],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: false,
    supportsBacktickIdentifiers: true,
    highlightsUppercaseIdentifiersAsTypes: true
  )
}
