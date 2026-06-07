import CodeckCore
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PresentationDocument: FileDocument {
  static var readableContentTypes: [UTType] {
    [.codeckDeck, .legacyMarkdown]
  }

  static var writableContentTypes: [UTType] {
    [.codeckDeck]
  }

  var deck: PresentationDeck

  init(deck: PresentationDeck = .blank) {
    self.deck = deck
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }

    let text = String(decoding: data, as: UTF8.self)
    deck = PresentationDeck(markdownDocument: text)
  }

  func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
    guard let data = deck.deckDocument.data(using: .utf8) else {
      throw CocoaError(.fileWriteInapplicableStringEncoding)
    }

    return FileWrapper(regularFileWithContents: data)
  }
}
