import UniformTypeIdentifiers

extension UTType {
    static let codeckDeck = UTType(exportedAs: "com.luku.Codeck.mdeck", conformingTo: .plainText)
    static let legacyMarkdown = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}
