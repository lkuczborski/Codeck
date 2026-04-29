extension SyntaxHighlighter {
  static let javaScriptDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "abstract", "as", "async", "await", "break", "case", "catch", "class", "const", "constructor", "continue",
      "debugger", "declare", "default", "delete", "do", "else", "enum", "export", "extends", "finally", "for",
      "from", "function", "get", "if", "implements", "import", "in", "instanceof", "interface", "is", "keyof",
      "let", "module", "namespace", "new", "of", "private", "protected", "public", "readonly", "return", "set",
      "static", "super", "switch", "throw", "try", "type", "typeof", "var", "void", "while", "with", "yield"
    ],
    types: [
      "Array", "Boolean", "Date", "Map", "Number", "Object", "Promise", "Record", "RegExp", "Set", "String",
      "boolean", "never", "number", "string", "symbol", "unknown"
    ],
    literals: ["false", "null", "true", "undefined"],
    lineComments: ["//"],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: true,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: false
  )
}
