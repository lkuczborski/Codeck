extension SyntaxHighlighter {
  static let pythonDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class", "continue", "def",
      "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda",
      "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"
    ],
    types: ["bool", "bytes", "dict", "float", "frozenset", "int", "list", "object", "set", "str", "tuple"],
    literals: ["False", "None", "True", "false", "none", "true"],
    lineComments: ["#"],
    blockComments: [],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: false,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: false
  )
}
