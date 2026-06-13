enum DeckAssistantRunPolicy {
    static func canRun(
        _ action: DeckAssistantQuickAction,
        allowsWebResearch: Bool,
        isRunning: Bool
    ) -> Bool {
        guard !isRunning else { return false }
        return allowsWebResearch || !action.requiresWebResearch
    }
}
