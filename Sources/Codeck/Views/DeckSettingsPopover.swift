import CodeckCore
import SwiftUI

struct DeckSettingsPopover: View {
  @Binding var settings: PresentationSettings
  @ObservedObject var modelCatalog: CodexModelCatalogStore

  var body: some View {
    Form {
      Picker("Theme", selection: $settings.theme) {
        ForEach(PresentationTheme.allCases) { theme in
          Text(theme.displayName).tag(theme)
        }
      }

      Picker("Model", selection: $settings.codex.model) {
        ForEach(modelOptions) { option in
          Text(option.displayName).tag(option.id)
        }
      }
      .onChange(of: settings.codex.model) { _, _ in
        normalizeReasoning()
      }

      if !selectedModel.description.isEmpty {
        Text(selectedModel.description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if modelCatalog.isRefreshing {
        ProgressView()
          .controlSize(.small)
      }

      Picker("Reasoning", selection: $settings.codex.reasoning) {
        ForEach(selectedModel.supportedReasoningEfforts) { effort in
          Text(effort.displayName).tag(effort)
        }
      }

      Picker("Sandbox", selection: $settings.codex.sandbox) {
        Text("Read Only").tag("read-only")
        Text("Workspace Write").tag("workspace-write")
        Text("Danger Full Access").tag("danger-full-access")
      }
    }
    .formStyle(.grouped)
    .padding(16)
    .frame(width: 340)
    .codeckWorkspaceBackground()
    .task {
      await modelCatalog.refresh()
      applyLiveModelDefaultsIfNeeded()
    }
    .onChange(of: modelCatalog.models) { _, _ in
      applyLiveModelDefaultsIfNeeded()
    }
  }

  private var modelOptions: [CodexModelOption] {
    modelCatalog.modelOptions(
      including: settings.codex.model,
      selectedReasoning: settings.codex.reasoning
    )
  }

  private var selectedModel: CodexModelOption {
    modelOptions.first(where: { $0.id == settings.codex.model }) ?? CodexModelOption.defaultOption(in: modelOptions)
  }

  private func applyLiveModelDefaultsIfNeeded() {
    let liveDefaultModelID = modelCatalog.defaultModelID()
    if settings.codex.model == CodexModelOption.defaultModelID, liveDefaultModelID != settings.codex.model {
      settings.codex.model = liveDefaultModelID
    }

    normalizeReasoning()
  }

  private func normalizeReasoning() {
    settings.codex.reasoning = CodexModelOption.normalizedReasoning(
      settings.codex.reasoning,
      for: settings.codex.model,
      in: modelOptions
    )
  }
}
