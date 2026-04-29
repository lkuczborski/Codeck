extension SyntaxHighlighter {
  static let sqlDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "add", "alter", "and", "as", "asc", "between", "by", "case", "create", "delete", "desc", "distinct",
      "drop", "else", "end", "from", "group", "having", "in", "insert", "into", "is", "join", "left", "like",
      "limit", "not", "null", "on", "or", "order", "outer", "right", "select", "set", "table", "then", "union",
      "update", "values", "when", "where"
    ],
    types: ["bigint", "boolean", "date", "decimal", "double", "float", "int", "integer", "json", "text", "varchar"],
    literals: ["false", "null", "true"],
    lineComments: ["--"],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: true,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: false
  )
}
