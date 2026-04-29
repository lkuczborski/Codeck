extension SyntaxHighlighter {
  static let rustDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "fn",
      "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return", "self",
      "Self", "static", "struct", "super", "trait", "type", "unsafe", "use", "where", "while"
    ],
    types: ["Box", "Option", "Result", "String", "Vec", "bool", "char", "f32", "f64", "i32", "i64", "str", "u32", "u64"],
    literals: ["false", "None", "Some", "true"],
    lineComments: ["//"],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: false,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: true
  )
}
