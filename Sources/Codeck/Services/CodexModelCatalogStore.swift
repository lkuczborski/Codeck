import CodeckCore
import Combine
import Foundation

@MainActor
final class CodexModelCatalogStore: ObservableObject {
    @Published private(set) var models: [CodexModelOption]
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    private let defaults: UserDefaults
    private let fetch: @Sendable () async throws -> [CodexModelOption]
    private static let cacheKey = "Codeck.backendModelCatalog"

    init(defaults: UserDefaults = .standard,
         fetch: @escaping @Sendable () async throws -> [CodexModelOption] = { try await CodexModelListClient.fetchModels() })
    {
        self.defaults = defaults
        self.fetch = fetch
        models = defaults.data(forKey: Self.cacheKey).flatMap { try? JSONDecoder().decode([CodexModelOption].self, from: $0) } ?? []
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let liveModels = try await fetch()
            guard !liveModels.isEmpty else { throw CodexModelListClient.ClientError.missingResponse }
            models = liveModels
            if let data = try? JSONEncoder().encode(liveModels) { defaults.set(data, forKey: Self.cacheKey) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func modelOptions(including selectedModelID: String,
                      selectedReasoning: CodexReasoningEffort? = nil) -> [CodexModelOption]
    {
        if models.contains(where: { $0.id == selectedModelID }) { return models }
        // Preserve saved settings when the backend is unavailable or a model retires.
        // This entry does not claim backend availability or invent supported levels.
        let reasoning = selectedReasoning ?? CodexModelOption.normalizedReasoning(nil, for: selectedModelID)
        let savedModel = CodexModelOption(
            id: selectedModelID, displayName: selectedModelID,
            description: "Saved model from this deck.",
            supportedReasoningEfforts: [reasoning], defaultReasoningEffort: reasoning, isDefault: false
        )
        return [savedModel] + models
    }
}
