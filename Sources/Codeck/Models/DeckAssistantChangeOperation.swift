enum DeckAssistantChangeOperation: Hashable {
    case insert(position: Int)
    case replace(index: Int)
}
