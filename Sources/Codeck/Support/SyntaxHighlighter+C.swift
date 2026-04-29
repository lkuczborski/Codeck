extension SyntaxHighlighter {
  static let cDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "auto", "bool", "break", "case", "char", "class", "const", "continue", "default", "delete", "do", "double",
      "else", "enum", "extern", "float", "for", "if", "inline", "int", "long", "namespace", "new", "private",
      "protected", "public", "return", "short", "signed", "sizeof", "static", "struct", "switch", "template",
      "typedef", "typename", "union", "unsigned", "using", "virtual", "void", "while"
    ],
    types: ["BOOL", "CGFloat", "NSInteger", "NSString", "NSUInteger", "size_t", "std"],
    literals: ["FALSE", "NULL", "TRUE", "false", "nullptr", "true"],
    lineComments: ["//"],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: false,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: true
  )
}
