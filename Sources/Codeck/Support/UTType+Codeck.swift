import UniformTypeIdentifiers

extension UTType {
  static let codeckMarkdown = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}
