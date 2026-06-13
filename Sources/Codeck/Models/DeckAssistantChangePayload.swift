struct DeckAssistantChangePayload: Decodable {
    var id: String?
    var title: String?
    var detail: String?
    var operation: String
    var slideIndex: Int?
    var insertPosition: Int?
    var afterMarkdown: String
}
