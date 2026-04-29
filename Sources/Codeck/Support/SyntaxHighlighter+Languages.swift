extension SyntaxHighlighter {
  static let aliases: [String: String] = [
    "c#": "csharp",
    "cs": "csharp",
    "c++": "cpp",
    "docker": "dockerfile",
    "golang": "go",
    "htm": "html",
    "js": "javascript",
    "jsonc": "json",
    "md": "markdown",
    "mjs": "javascript",
    "objc": "objective-c",
    "py": "python",
    "rb": "ruby",
    "sh": "bash",
    "text": "plaintext",
    "ts": "typescript",
    "yml": "yaml"
  ]

  static let plainTextLanguages: Set<String> = [
    "plain",
    "plaintext",
    "text",
    "txt"
  ]

  static let genericDefinition = LanguageDefinition(
    family: .code,
    keywords: [],
    types: [],
    literals: ["true", "false", "null", "nil"],
    lineComments: ["//", "#"],
    blockComments: [("/*", "*/")],
    stringDelimiters: ["\"", "'"],
    supportsBacktickStrings: true,
    supportsBacktickIdentifiers: false,
    highlightsUppercaseIdentifiersAsTypes: false
  )

  static func definition(for language: String) -> LanguageDefinition? {
    switch language {
    case "swift":
      return swiftDefinition
    case "javascript", "typescript", "jsx", "tsx":
      return javaScriptDefinition
    case "python":
      return pythonDefinition
    case "bash", "shell", "zsh", "fish", "powershell":
      return shellDefinition
    case "json":
      return jsonDefinition
    case "yaml", "toml":
      return yamlDefinition
    case "html", "xml":
      return markupDefinition
    case "css", "scss", "less":
      return cssDefinition
    case "markdown":
      return markdownDefinition
    case "diff", "patch":
      return diffDefinition
    case "sql":
      return sqlDefinition
    case "rust":
      return rustDefinition
    case "go":
      return goDefinition
    case "java", "kotlin":
      return javaDefinition
    case "c", "cpp", "objective-c", "csharp":
      return cDefinition
    case "ruby":
      return rubyDefinition
    case "php":
      return phpDefinition
    default:
      return nil
    }
  }
}
