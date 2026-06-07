import Foundation

public struct CodeckDeckFileStore {
  private let fileManager: FileManager

  public init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  public func loadDeck(at url: URL) throws -> PresentationDeck {
    guard fileManager.fileExists(atPath: url.path) else {
      throw CodeckDeckFileError.fileNotFound(url.path)
    }

    let data = try Data(contentsOf: url)
    let markdown = String(decoding: data, as: UTF8.self)
    return PresentationDeck(markdownDocument: markdown)
  }

  @discardableResult
  public func createDeck(
    at url: URL,
    settings: PresentationSettings = .default,
    slideMarkdown: [String] = [],
    overwrite: Bool = false,
    createDirectories: Bool = false
  ) throws -> PresentationDeck {
    if fileManager.fileExists(atPath: url.path), !overwrite {
      throw CodeckDeckFileError.fileAlreadyExists(url.path)
    }

    if createDirectories {
      let directory = url.deletingLastPathComponent()
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    let slides = slideMarkdown.map { Slide(markdown: $0) }
    let deck = PresentationDeck(settings: settings, slides: slides)
    try saveDeck(deck, at: url)
    return deck
  }

  public func saveDeck(_ deck: PresentationDeck, at url: URL) throws {
    guard let data = deck.deckDocument.data(using: .utf8) else {
      throw CodeckDeckFileError.invalidUTF8
    }

    try data.write(to: url, options: .atomic)
  }
}
