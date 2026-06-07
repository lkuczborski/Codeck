struct DeckAssistantChange: Identifiable, Hashable {
  let id: String
  var title: String
  var detail: String
  var operation: DeckAssistantChangeOperation
  var beforeMarkdown: String?
  var afterMarkdown: String

  var locationLabel: String {
    switch operation {
    case let .insert(position):
      "Insert at \(position + 1)"
    case let .replace(index):
      "Slide \(index + 1)"
    }
  }
}
