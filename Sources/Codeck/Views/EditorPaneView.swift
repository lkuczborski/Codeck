import SwiftUI

struct EditorPaneView: View {
  @Binding var slide: Slide
  @Binding var settings: PresentationSettings
  @ObservedObject var modelCatalog: CodexModelCatalogStore
  let onInsertCodexBlock: () -> Void
  @State private var showsDeckSettings = false

  var body: some View {
    VStack(spacing: 0) {
      toolbar

      TextEditor(text: $slide.markdown)
        .font(.system(size: 15, design: .monospaced))
        .scrollContentBackground(.hidden)
        .padding(10)
        .background(.ultraThinMaterial)
    }
  }

  private var toolbar: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        themePicker(width: 232)

        Spacer(minLength: 10)

        deckSettingsButton
          .labelStyle(.titleAndIcon)

        insertCodexButton
          .labelStyle(.titleAndIcon)
      }

      HStack(spacing: 8) {
        themePicker(width: 216)

        Spacer(minLength: 8)

        deckSettingsButton
          .labelStyle(.iconOnly)

        insertCodexButton
          .labelStyle(.iconOnly)
      }
    }
    .padding(10)
    .codeckGlassSurface(cornerRadius: 16, interactive: true)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
  }

  private func themePicker(width: CGFloat) -> some View {
    Picker("Theme", selection: $settings.theme) {
      ForEach(PresentationTheme.allCases) { theme in
        Text(theme.displayName).tag(theme)
      }
    }
    .pickerStyle(.menu)
    .fixedSize(horizontal: true, vertical: false)
    .frame(width: width, alignment: .leading)
    .layoutPriority(1)
  }

  private var deckSettingsButton: some View {
    Button {
      showsDeckSettings.toggle()
    } label: {
      Label("Deck Settings", systemImage: "slider.horizontal.3")
    }
    .codeckGlassButtonStyle()
    .help("Edit deck-level Codex settings")
    .popover(isPresented: $showsDeckSettings, arrowEdge: .bottom) {
      DeckSettingsPopover(settings: $settings, modelCatalog: modelCatalog)
    }
  }

  private var insertCodexButton: some View {
    Button(action: onInsertCodexBlock) {
      Label("Insert Codex Session", systemImage: "terminal")
    }
    .codeckGlassButtonStyle(prominent: true)
    .help("Insert live Codex session")
  }
}

private struct DeckSettingsPopover: View {
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
    .background(.thinMaterial)
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
