import CodeckCore
import Foundation

@MainActor
final class LiveMCPDocumentRegistry {
  static let shared = LiveMCPDocumentRegistry()

  private var documents: [UUID: LiveMCPDocumentSession] = [:]
  private var activeDocumentID: UUID?

  private init() {}

  func register(_ session: LiveMCPDocumentSession) {
    documents[session.id] = session
    activeDocumentID = session.id
  }

  func unregister(_ id: UUID) {
    documents[id] = nil
    if activeDocumentID == id {
      activeDocumentID = documents.keys.sorted { $0.uuidString < $1.uuidString }.first
    }
  }

  func activate(_ id: UUID) {
    guard documents[id] != nil else { return }
    activeDocumentID = id
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

    if let activeDocumentID, let document = documents[activeDocumentID] {
      return document
    }

    if documents.count == 1, let document = documents.values.first {
      return document
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
