import SwiftUI

struct DocumentWindowView: View {
  @Binding var document: PresentationDocument
  let fileURL: URL?

  @StateObject private var sessionStore = CodexSessionStore()
  @StateObject private var modelCatalog = CodexModelCatalogStore()
  @StateObject private var presentationPresenter = PresentationPresenter()
  @SceneStorage("selectedSlideID") private var selectedSlideIDString: String?
  @SceneStorage("isPreviewVisible") private var isPreviewVisible = true
  @SceneStorage("compactDetailPane") private var compactPaneRawValue = "editor"
  @AppStorage(AppAppearanceMode.storageKey) private var appAppearanceModeRawValue = AppAppearanceMode.automatic.rawValue
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var appearanceRefreshID = UUID()

  private var selectedSlideID: Slide.ID? {
    get {
      selectedSlideIDString.flatMap(UUID.init(uuidString:))
    }
    nonmutating set {
      selectedSlideIDString = newValue?.uuidString
    }
  }

  private var appAppearanceMode: AppAppearanceMode {
    get {
      AppAppearanceMode(rawValue: appAppearanceModeRawValue) ?? .automatic
    }
    nonmutating set {
      appAppearanceModeRawValue = newValue.rawValue
    }
  }

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      SidebarView(
        deck: document.deck,
        selection: Binding(
          get: { selectedSlideID },
          set: { selectedSlideID = $0 }
        ),
        onAddSlide: addSlide,
        onDuplicateSlide: duplicateSlide,
        onDeleteSlide: deleteSlide,
        onMoveSlides: moveSlides
      )
      .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    } detail: {
      detail
    }
    .frame(minWidth: 680, minHeight: 500)
    .toolbar {
      if #available(macOS 26.0, *) {
        ToolbarItem(placement: .automatic) {
          appearanceToolbarControl
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarSpacer(.fixed)

        ToolbarItem(placement: .automatic) {
          playToolbarButton
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarSpacer(.fixed)

        ToolbarItem(placement: .automatic) {
          previewVisibilityToolbarButton
        }
        .sharedBackgroundVisibility(.hidden)
      } else {
        ToolbarItem(placement: .automatic) {
          appearanceToolbarControl
        }

        ToolbarItem(placement: .automatic) {
          playToolbarButton
        }

        ToolbarItem(placement: .automatic) {
          previewVisibilityToolbarButton
        }
      }
    }
    .focusedValue(\.previewVisibility, $isPreviewVisible)
    .onAppear(perform: ensureSelection)
    .onAppear(perform: applyStoredAppAppearance)
    .onChange(of: appAppearanceModeRawValue) { _, rawValue in
      applyAppAppearance(rawValue: rawValue)
    }
    .onChange(of: document.deck.slides) { _, _ in
      ensureSelection()
    }
    .task {
      await modelCatalog.refresh()
      applyLiveModelDefaultsIfNeeded()
    }
    .onChange(of: modelCatalog.models) { _, _ in
      applyLiveModelDefaultsIfNeeded()
    }
  }

  private var appearanceToolbarControl: some View {
    AppAppearanceSelector(
      selection: Binding(
        get: { appAppearanceMode },
        set: { mode in setAppAppearanceMode(mode) }
      )
    )
    .help("Choose app appearance")
  }

  private var playToolbarButton: some View {
    Button {
      presentationPresenter.present(
        deck: document.deck,
        selectedSlideID: selectedSlideID,
        baseURL: fileURL?.deletingLastPathComponent(),
        sessions: sessionStore
      )
    } label: {
      Label("Play", systemImage: "play.fill")
    }
    .help("Start presentation")
    .codeckToolbarIconButtonStyle(prominent: true)
  }

  private var previewVisibilityToolbarButton: some View {
    Button {
      isPreviewVisible.toggle()
    } label: {
      Label(isPreviewVisible ? "Hide Preview" : "Show Preview", systemImage: "sidebar.right")
    }
    .help(isPreviewVisible ? "Hide preview" : "Show preview")
    .codeckToolbarIconButtonStyle()
  }

  @ViewBuilder
  private var detail: some View {
    if let slide = selectedSlideBinding {
      GeometryReader { proxy in
        let isCompact = proxy.size.width < 780

        if isPreviewVisible, isCompact {
          compactDetail(slide)
        } else if isPreviewVisible {
          HSplitView {
            editorPane(slide)
              .frame(minWidth: 320, idealWidth: 520)

            previewPane(slide.wrappedValue)
              .frame(minWidth: 340, idealWidth: 640)
          }
        } else {
          editorPane(slide)
        }
      }
    } else {
      ContentUnavailableView("No Slide", systemImage: "rectangle.stack", description: Text("Create a slide to start editing."))
    }
  }

  private func compactDetail(_ slide: Binding<Slide>) -> some View {
    VStack(spacing: 0) {
      Picker("Pane", selection: compactPaneBinding) {
        ForEach(CompactDetailPane.allCases) { pane in
          Label(pane.title, systemImage: pane.systemImage)
            .tag(pane)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(8)
      .codeckGlassSurface(cornerRadius: 14, interactive: true)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)

      switch compactPane {
      case .editor:
        editorPane(slide)
      case .preview:
        previewPane(slide.wrappedValue)
      }
    }
  }

  private func editorPane(_ slide: Binding<Slide>) -> some View {
    EditorPaneView(
      slide: slide,
      settings: $document.deck.settings,
      modelCatalog: modelCatalog,
      appearanceRefreshID: appearanceRefreshID
    )
  }

  private func previewPane(_ slide: Slide) -> some View {
    PreviewPaneView(
      slide: slide,
      theme: document.deck.theme,
      sessions: sessionStore,
      baseURL: fileURL?.deletingLastPathComponent(),
      onRunBlock: { block in
        sessionStore.run(block, settings: document.deck.settings.codex, workingDirectory: fileURL?.deletingLastPathComponent())
      },
      onRunAll: { blocks in
        sessionStore.runAll(blocks, settings: document.deck.settings.codex, workingDirectory: fileURL?.deletingLastPathComponent())
      }
    )
  }

  private var selectedSlideBinding: Binding<Slide>? {
    guard let index = selectedSlideIndex else { return nil }
    let slideID = document.deck.slides[index].id
    return Binding(
      get: {
        if let currentIndex = document.deck.slides.firstIndex(where: { $0.id == slideID }) {
          return document.deck.slides[currentIndex]
        }
        return document.deck.slides[selectedSlideIndex ?? document.deck.slides.startIndex]
      },
      set: { replaceMarkdown(for: slideID, with: $0.markdown) }
    )
  }

  private var selectedSlideIndex: Int? {
    if let selectedSlideID, let index = document.deck.slides.firstIndex(where: { $0.id == selectedSlideID }) {
      return index
    }
    return document.deck.slides.indices.first
  }

  private func ensureSelection() {
    if selectedSlideIndex == nil {
      selectedSlideID = document.deck.slides.first?.id
    } else if selectedSlideID == nil {
      selectedSlideID = document.deck.slides.first?.id
    }
  }

  private func addSlide() {
    var deck = document.deck
    let newID = deck.addSlide(after: selectedSlideID)
    document.deck = deck
    selectedSlideID = newID
  }

  private func duplicateSlide() {
    var deck = document.deck
    if let newID = deck.duplicateSlide(selectedSlideID) {
      document.deck = deck
      selectedSlideID = newID
    }
  }

  private func deleteSlide() {
    var deck = document.deck
    selectedSlideID = deck.deleteSlide(selectedSlideID)
    document.deck = deck
  }

  private func moveSlides(from source: IndexSet, to destination: Int) {
    var deck = document.deck
    deck.slides.move(fromOffsets: source, toOffset: destination)
    document.deck = deck
  }

  private func replaceMarkdown(for slideID: Slide.ID, with markdown: String) {
    var deck = document.deck
    guard let result = deck.replaceSlideMarkdown(for: slideID, with: markdown) else {
      return
    }

    document.deck = deck
    if result.didSplit {
      selectedSlideID = result.selectedSlideID
    }
  }

  private func setAppAppearanceMode(_ mode: AppAppearanceMode) {
    applyAppAppearance(mode)
    appAppearanceModeRawValue = mode.rawValue
  }

  private func applyStoredAppAppearance() {
    applyAppAppearance(rawValue: appAppearanceModeRawValue)
  }

  private func applyAppAppearance(_ mode: AppAppearanceMode) {
    AppAppearanceController.apply(mode)
    appearanceRefreshID = UUID()
  }

  private func applyAppAppearance(rawValue: String) {
    AppAppearanceController.apply(rawValue: rawValue)
    appearanceRefreshID = UUID()
  }

  private func applyLiveModelDefaultsIfNeeded() {
    let liveDefaultModelID = modelCatalog.defaultModelID()
    if document.deck.settings.codex.model == CodexModelOption.defaultModelID,
       liveDefaultModelID != document.deck.settings.codex.model {
      document.deck.settings.codex.model = liveDefaultModelID
    }

    document.deck.settings.codex.reasoning = CodexModelOption.normalizedReasoning(
      document.deck.settings.codex.reasoning,
      for: document.deck.settings.codex.model,
      in: modelCatalog.modelOptions(
        including: document.deck.settings.codex.model,
        selectedReasoning: document.deck.settings.codex.reasoning
      )
    )
  }

  private var compactPane: CompactDetailPane {
    CompactDetailPane(rawValue: compactPaneRawValue) ?? .editor
  }

  private var compactPaneBinding: Binding<CompactDetailPane> {
    Binding(
      get: { compactPane },
      set: { compactPaneRawValue = $0.rawValue }
    )
  }
}

private enum CompactDetailPane: String, CaseIterable, Identifiable {
  case editor
  case preview

  var id: String { rawValue }

  var title: String {
    switch self {
    case .editor:
      "Editor"
    case .preview:
      "Preview"
    }
  }

  var systemImage: String {
    switch self {
    case .editor:
      "pencil"
    case .preview:
      "play.rectangle"
    }
  }
}
