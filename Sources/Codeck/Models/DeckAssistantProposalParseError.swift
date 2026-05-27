import Foundation

enum DeckAssistantProposalParseError: LocalizedError, Equatable {
  case missingJSONObject
  case invalidJSON(String)
  case noValidChanges

  var errorDescription: String? {
    switch self {
    case .missingJSONObject:
      "Codex did not return a JSON proposal."
    case .invalidJSON(let message):
      "Codex returned JSON that could not be parsed: \(message)"
    case .noValidChanges:
      "Codex returned a proposal, but none of the changes matched the current deck."
    }
  }
}
