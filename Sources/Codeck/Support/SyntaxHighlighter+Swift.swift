extension SyntaxHighlighter {
  static let swiftDefinition = LanguageDefinition(
    family: .code,
    keywords: [
      "Any", "Self", "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch", "class",
      "continue", "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough", "fileprivate",
      "for", "func", "get", "guard", "if", "import", "in", "indirect", "infix", "init", "inout", "internal", "is",
      "let", "mutating", "nonisolated", "open", "operator", "override", "postfix", "precedencegroup", "prefix",
      "private", "protocol", "public", "rethrows", "return", "set", "some", "static", "struct", "subscript",
      "super", "switch", "throw", "throws", "try", "typealias", "var", "where", "while"
    ],
    types: [
      "Array", "Binding", "Bool", "CGFloat", "CGPoint", "CGRect", "CGSize", "Character", "Color", "Data", "Date",
      "Dictionary", "Double", "Float", "Int", "MainActor", "Never", "Optional", "Result", "Set", "State",
      "StateObject", "String", "Task", "URL", "View", "Void"
    ],
    literals: ["false", "nil", "self", "true"],
    lineComments: ["//"],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\""],
    supportsBacktickStrings: false,
    supportsBacktickIdentifiers: true,
    highlightsUppercaseIdentifiersAsTypes: true
  )
}
