import Combine
import Foundation

@MainActor
final class CodexModelCatalogStore: ObservableObject {
  @Published private(set) var models = CodexModelOption.fallbackOptions
  @Published private(set) var isRefreshing = false
  @Published private(set) var errorMessage: String?

  func refresh() async {
    guard !isRefreshing else { return }

    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let liveModels = try await CodexModelListClient.fetchModels()
      guard !liveModels.isEmpty else { return }

      models = liveModels
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func modelOptions(
    including selectedModelID: String,
    selectedReasoning: CodexReasoningEffort? = nil
  ) -> [CodexModelOption] {
    if models.contains(where: { $0.id == selectedModelID }) {
      return models
    }

    var supportedReasoningEfforts = CodexReasoningEffort.allCases
    if let selectedReasoning, !supportedReasoningEfforts.contains(selectedReasoning) {
      supportedReasoningEfforts.insert(selectedReasoning, at: 0)
    }

    let savedModel = CodexModelOption(
      id: selectedModelID,
      displayName: selectedModelID,
      description: "Saved model from this deck.",
      supportedReasoningEfforts: supportedReasoningEfforts,
      defaultReasoningEffort: .medium,
      isDefault: false
    )
    return [savedModel] + models
  }

  func defaultModelID() -> String {
    CodexModelOption.defaultOption(in: models).id
  }

  func option(for modelID: String) -> CodexModelOption? {
    models.first { $0.id == modelID }
  }
}
