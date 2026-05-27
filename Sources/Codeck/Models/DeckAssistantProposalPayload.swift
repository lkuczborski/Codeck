struct DeckAssistantProposalPayload: Decodable {
  var title: String?
  var summary: String?
  var changes: [DeckAssistantChangePayload]
}
