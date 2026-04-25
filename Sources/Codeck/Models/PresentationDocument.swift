import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PresentationDocument: FileDocument {
  static var readableContentTypes: [UTType] {
    [.codeckMarkdown, .plainText]
  }

  static var writableContentTypes: [UTType] {
    [.codeckMarkdown]
  }

  var deck: PresentationDeck

  init(deck: PresentationDeck = .sample) {
    self.deck = deck
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }

    let text = String(decoding: data, as: UTF8.self)
    deck = PresentationDeck(markdownDocument: text)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    guard let data = deck.markdownDocument.data(using: .utf8) else {
      throw CocoaError(.fileWriteInapplicableStringEncoding)
    }

    return FileWrapper(regularFileWithContents: data)
  }
}
