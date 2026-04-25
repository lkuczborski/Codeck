import UniformTypeIdentifiers

extension UTType {
  static let codeckDeck = UTType(exportedAs: "dev.local.codeck.mdeck", conformingTo: .plainText)
  static let legacyMarkdown = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}
