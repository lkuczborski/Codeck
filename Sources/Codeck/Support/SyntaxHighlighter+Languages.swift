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
    "yml": "yaml",
  ]

  static let plainTextLanguages: Set<String> = [
    "plain",
    "plaintext",
    "text",
    "txt",
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
      swiftDefinition
    case "javascript", "typescript", "jsx", "tsx":
      javaScriptDefinition
    case "python":
      pythonDefinition
    case "bash", "shell", "zsh", "fish", "powershell":
      shellDefinition
    case "json":
      jsonDefinition
    case "yaml", "toml":
      yamlDefinition
    case "html", "xml":
      markupDefinition
    case "css", "scss", "less":
      cssDefinition
    case "markdown":
      markdownDefinition
    case "diff", "patch":
      diffDefinition
    case "sql":
      sqlDefinition
    case "rust":
      rustDefinition
    case "go":
      goDefinition
    case "java", "kotlin":
      javaDefinition
    case "c", "cpp", "objective-c", "csharp":
      cDefinition
    case "ruby":
      rubyDefinition
    case "php":
      phpDefinition
    default:
      nil
    }
  }
}
