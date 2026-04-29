import SwiftUI

struct EditorPaneView: View {
  @Binding var slide: Slide
  @Binding var settings: PresentationSettings
  @ObservedObject var modelCatalog: CodexModelCatalogStore
  @StateObject private var editorController = MarkdownEditorController()
  @State private var showsDeckSettings = false

  var body: some View {
    VStack(spacing: 0) {
      toolbar

      MarkdownTextEditorView(text: $slide.markdown, controller: editorController)
        .id(slide.id)
        .background(.ultraThinMaterial)
    }
  }

  private var toolbar: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        themePicker(width: 232)

        toolbarSeparator

        editorControls(labelStyle: .titleAndIcon)

        Spacer(minLength: 10)

        deckSettingsButton
          .labelStyle(.titleAndIcon)
      }

      HStack(spacing: 8) {
        themePicker(width: 216)

        toolbarSeparator

        editorControls(labelStyle: .iconOnly)

        Spacer(minLength: 8)

        deckSettingsButton
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

  private func editorControls(labelStyle: EditorToolbarLabelStyle) -> some View {
    HStack(spacing: 8) {
      switch labelStyle {
      case .titleAndIcon:
        insertMenu
          .labelStyle(.titleAndIcon)
      case .iconOnly:
        insertMenu
          .labelStyle(.iconOnly)
      }

      toolbarSeparator

      formatButtons
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private var formatButtons: some View {
    HStack(spacing: 4) {
      ForEach(MarkdownTextStyle.allCases) { style in
        MarkdownStyleButton(
          style: style,
          isActive: editorController.activeStyles.contains(style),
          action: { editorController.toggle(style) }
        )
      }
    }
    .fixedSize(horizontal: true, vertical: false)
    .accessibilityElement(children: .contain)
  }

  private var toolbarSeparator: some View {
    Rectangle()
      .fill(Color.secondary.opacity(0.28))
      .frame(width: 1, height: 24)
      .padding(.horizontal, 2)
      .accessibilityHidden(true)
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

  private var insertMenu: some View {
    Menu {
      Section("Text") {
        insertButton(.heading1)
        insertButton(.heading2)
        insertButton(.heading3)
        insertButton(.paragraph)
        insertButton(.link)
      }

      Section("Blocks") {
        insertButton(.bulletedList)
        insertButton(.numberedList)
        insertButton(.blockquote)
        insertButton(.table)
        insertButton(.horizontalRule)
      }

      Section("Media and Code") {
        insertButton(.image)
        insertButton(.codeBlock)
        insertButton(.codexSession)
      }
    } label: {
      Label("Insert", systemImage: "plus")
    }
    .codeckGlassButtonStyle(prominent: true)
    .help("Insert Markdown element")
  }

  private func insertButton(_ insertion: MarkdownInsertion) -> some View {
    Button {
      editorController.insert(insertion, codexBlockNumber: slide.codexBlocks.count + 1)
    } label: {
      Label(insertion.title, systemImage: insertion.systemImage)
    }
  }
}

private enum EditorToolbarLabelStyle {
  case titleAndIcon
  case iconOnly
}

private struct MarkdownStyleButton: View {
  let style: MarkdownTextStyle
  let isActive: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      styledLabel
        .frame(width: 26, height: 24)
        .background(
          isActive ? Color.accentColor.opacity(0.24) : Color.clear,
          in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(isActive ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .help(style.help)
    .accessibilityLabel(style.title)
  }

  @ViewBuilder
  private var styledLabel: some View {
    let base = Text("a")
      .font(.system(size: 15, weight: .regular))

    switch style {
    case .bold:
      base.bold()
    case .italic:
      base.italic()
    case .inlineCode:
      base
        .font(.system(size: 14, design: .monospaced))
        .padding(.horizontal, 3)
        .background(Color.secondary.opacity(0.16), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    case .strikethrough:
      base.strikethrough()
    case .link:
      base.underline()
    }
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
