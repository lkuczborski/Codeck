import CodeckCore
import Foundation

@MainActor
final class LiveMCPDocumentRegistry {
  static let shared = LiveMCPDocumentRegistry()

  private var documents: [UUID: LiveMCPDocumentSession] = [:]

  private init() {}

  func register(_ session: LiveMCPDocumentSession) {
    documents[session.id] = session
  }

  func unregister(_ id: UUID) {
    documents[id] = nil
  }

  func listDocuments() -> [LiveMCPDocumentSession] {
    documents.values.sorted { lhs, rhs in
      lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }
  }

  func resolveDocument(id rawID: String?) throws -> LiveMCPDocumentSession {
    if let rawID, let id = UUID(uuidString: rawID), let document = documents[id] {
      return document
    }

    if let rawID, UUID(uuidString: rawID) == nil {
      throw LiveMCPError.invalidParams("document_id must be a UUID string.")
    }

    if let rawID, UUID(uuidString: rawID) != nil {
      throw LiveMCPError.invalidParams("No open Codeck document has document_id \(rawID).")
    }

    if documents.count == 1, let document = documents.values.first {
      return document
    }

    if documents.count > 1 {
      throw LiveMCPError.invalidParams("Multiple Codeck documents are open. Pass document_id from list_open_decks.")
    }

    throw LiveMCPError.operationFailed("No Codeck document is available. Open a deck in Codeck or pass document_id.")
  }
}

@MainActor
struct LiveMCPDocumentSession {
  let id: UUID
  let fileURL: () -> URL?
  let deck: () -> PresentationDeck
  let setDeck: (PresentationDeck) -> Void
  let selectedSlideIndex: () -> Int?
  let selectSlide: (Int) -> Void
  let present: () -> Void
  let dismissPresentation: () -> Void

  var displayName: String {
    if let fileURL = fileURL() {
      return fileURL.lastPathComponent
    }
    return deck().slides.first?.title ?? "Untitled Deck"
  }
}

enum LiveMCPError: LocalizedError {
  case invalidParams(String)
  case operationFailed(String)

  var jsonRPCCode: Int {
    switch self {
    case .invalidParams:
      -32602
    case .operationFailed:
      -32000
    }
  }

  var errorDescription: String? {
    switch self {
    case .invalidParams(let message), .operationFailed(let message):
      message
    }
  }
}
