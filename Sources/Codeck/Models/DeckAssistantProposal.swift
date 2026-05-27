import Foundation

struct DeckAssistantProposal: Identifiable, Hashable {
  let id: UUID
  var title: String
  var summary: String
  var changes: [DeckAssistantChange]

  init(
    id: UUID = UUID(),
    title: String,
    summary: String,
    changes: [DeckAssistantChange]
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.changes = changes
  }

  static let empty = DeckAssistantProposal(
    title: "No proposal yet",
    summary: "Ask Codex to review the current slide or the full deck.",
    changes: []
  )
}
