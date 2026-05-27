import AppKit
import CodeckCore
import SwiftUI

struct DocumentWindowView: View {
  @Binding var document: PresentationDocument
  let fileURL: URL?

  @StateObject private var sessionStore = CodexSessionStore()
  @StateObject private var modelCatalog = CodexModelCatalogStore()
  @StateObject private var presentationPresenter = PresentationPresenter()
  @StateObject private var presentationPreviewPresenter = PresentationPreviewPresenter()
  @SceneStorage("selectedSlideID") private var selectedSlideIDString: String?
  @SceneStorage("isRightUtilityVisible") private var isRightUtilityVisible = true
  @SceneStorage("rightUtilityMode") private var rightUtilityModeRawValue = DocumentRightUtilityPane.preview.rawValue
  @SceneStorage("compactDetailPaneSelection") private var compactPaneRawValue = CompactDetailPane.editor.rawValue
  @AppStorage(AppAppearanceMode.storageKey) private var appAppearanceModeRawValue = AppAppearanceMode.automatic.rawValue
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var appearanceRefreshID = UUID()
  @State private var liveMCPDocumentID = UUID()
  @State private var isShowingTemplatePicker = false
  @State private var isPlayPreviewPopoverPresented = false
  @State private var isPlayButtonHovered = false
  @State private var isPlayPreviewPopoverHovered = false
  @State private var playPreviewSkimmedSlideIndex: Int?
  @State private var playPreviewHoverRequestID = UUID()

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
        onAddTemplateSlide: showTemplatePicker,
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
          rightUtilityToolbarButton
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
          rightUtilityToolbarButton
        }
      }
    }
    .focusedValue(\.rightUtilityActions, rightUtilityActions)
    .focusedSceneValue(
      \.slideCommandActions,
      SlideCommandActions(
        document: $document,
        selectedSlideIDString: $selectedSlideIDString,
        presentTemplatePicker: showTemplatePicker
      )
    )
    .sheet(isPresented: $isShowingTemplatePicker) {
      SlideTemplatePickerView(
        theme: document.deck.theme,
        onCancel: hideTemplatePicker,
        onInsert: insertTemplateSlide
      )
    }
    .onAppear(perform: ensureSelection)
    .onAppear(perform: applyStoredAppAppearance)
    .onAppear(perform: registerLiveMCPDocument)
    .onDisappear {
      unregisterLiveMCPDocument()
      presentationPreviewPresenter.dismiss()
    }
    .onChange(of: fileURL) { _, _ in
      registerLiveMCPDocument()
      updateDetachedPresentationPreview()
    }
    .onChange(of: appAppearanceModeRawValue) { _, rawValue in
      applyAppAppearance(rawValue: rawValue)
    }
    .onChange(of: document.deck.slides) { _, _ in
      ensureSelection()
      updateDetachedPresentationPreview()
    }
    .onChange(of: document.deck.settings) { _, _ in
      updateDetachedPresentationPreview()
    }
    .onChange(of: selectedSlideIDString) { _, _ in
      updateDetachedPresentationPreview()
    }
    .onChange(of: presentationPreviewPresenter.isPresented) { _, isPresented in
      if isPresented {
        hidePlayPreviewPopover()
      }
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
      hidePlayPreviewPopover()
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
    .onHover(perform: setPlayButtonPreviewHover)
    .popover(isPresented: $isPlayPreviewPopoverPresented, arrowEdge: .bottom) {
      playPreviewPopover
    }
  }

  private var playPreviewPopover: some View {
    PresentationSlidePreviewPopover(
      deck: document.deck,
      selectedSlideID: effectiveSelectedSlideID,
      sessions: sessionStore,
      baseURL: fileURL?.deletingLastPathComponent(),
      skimmedSlideIndex: $playPreviewSkimmedSlideIndex,
      onHoverChanged: setPlayPreviewPopoverHover,
      onDetach: showDetachedPresentationPreview
    )
  }

  private var rightUtilityToolbarButton: some View {
    Button {
      toggleRightUtilityVisibility()
    } label: {
      Label(isRightUtilityVisible ? "Hide Right Pane" : "Show Right Pane", systemImage: "sidebar.right")
    }
    .help(isRightUtilityVisible ? "Hide right pane" : "Show right pane")
    .codeckToolbarIconButtonStyle()
  }

  @ViewBuilder
  private var detail: some View {
    if let slide = selectedSlideBinding {
      GeometryReader { proxy in
        let isCompact = proxy.size.width < 780

        detailWorkspace(slide, isCompact: isCompact)
      }
    } else {
      ContentUnavailableView("No Slide", systemImage: "rectangle.stack", description: Text("Create a slide to start editing."))
    }
  }

  @ViewBuilder
  private func detailWorkspace(_ slide: Binding<Slide>, isCompact: Bool) -> some View {
    if isCompact {
      compactDetail(slide)
    } else if isRightUtilityVisible {
      HSplitView {
        editorPane(slide)
          .frame(minWidth: 320, idealWidth: 520)

        rightUtilityContainer(slide)
          .frame(minWidth: 340, idealWidth: rightUtilityIdealWidth)
      }
    } else {
      editorPane(slide)
    }
  }

  private func rightUtilityContainer(_ slide: Binding<Slide>) -> some View {
    VStack(spacing: 0) {
      rightUtilityModeSelector

      rightUtilityPane(slide)
    }
  }

  private var rightUtilityModeSelector: some View {
    ZStack {
      Picker("Right Pane", selection: rightUtilityModeBinding) {
        ForEach(DocumentRightUtilityPane.allCases) { pane in
          Label(pane.title, systemImage: pane.systemImage)
            .tag(pane)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 260)
    }
    .frame(maxWidth: .infinity)
    .padding(10)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private func rightUtilityPane(_ slide: Binding<Slide>) -> some View {
    switch rightUtilityMode {
    case .preview:
      previewPane(slide.wrappedValue)
    case .assistant:
      deckAssistantPane
    }
  }

  private var deckAssistantPane: some View {
    DeckAssistantPanelView(
      deck: document.deck,
      selectedSlideIndex: effectiveSelectedSlideIndex,
      settings: document.deck.settings.codex,
      workingDirectory: fileURL?.deletingLastPathComponent(),
      sessions: sessionStore,
      onApply: applyAssistantChanges
    )
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
      case .assistant:
        deckAssistantPane
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

  private func showDetachedPresentationPreview(startingAt slideIndex: Int?) {
    hidePlayPreviewPopover()
    presentationPreviewPresenter.present(
      deck: document.deck,
      selectedSlideID: effectiveSelectedSlideID,
      fallbackSlideIndex: clampedSlideIndex(slideIndex),
      baseURL: fileURL?.deletingLastPathComponent(),
      sessions: sessionStore,
      anchorScreenPoint: NSEvent.mouseLocation
    )
  }

  private func setPlayButtonPreviewHover(_ isHovered: Bool) {
    isPlayButtonHovered = isHovered
    guard !presentationPreviewPresenter.isPresented else {
      hidePlayPreviewPopover()
      return
    }

    if isHovered {
      schedulePlayPreviewPopoverPresentation()
    } else {
      schedulePlayPreviewPopoverDismiss()
    }
  }

  private func setPlayPreviewPopoverHover(_ isHovered: Bool) {
    isPlayPreviewPopoverHovered = isHovered
    if isHovered {
      showPlayPreviewPopover()
    } else {
      schedulePlayPreviewPopoverDismiss()
    }
  }

  private func schedulePlayPreviewPopoverPresentation() {
    guard !presentationPreviewPresenter.isPresented else { return }

    let requestID = UUID()
    playPreviewHoverRequestID = requestID

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      guard playPreviewHoverRequestID == requestID,
            isPlayButtonHovered,
            !presentationPreviewPresenter.isPresented else { return }
      showPlayPreviewPopover()
    }
  }

  private func showPlayPreviewPopover() {
    guard !presentationPreviewPresenter.isPresented else { return }
    isPlayPreviewPopoverPresented = true
  }

  private func schedulePlayPreviewPopoverDismiss() {
    playPreviewHoverRequestID = UUID()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
      guard !isPlayButtonHovered, !isPlayPreviewPopoverHovered else { return }
      hidePlayPreviewPopover()
    }
  }

  private func hidePlayPreviewPopover() {
    playPreviewHoverRequestID = UUID()
    isPlayPreviewPopoverPresented = false
    isPlayPreviewPopoverHovered = false
    playPreviewSkimmedSlideIndex = nil
  }

  private func updateDetachedPresentationPreview() {
    presentationPreviewPresenter.update(
      deck: document.deck,
      selectedSlideID: effectiveSelectedSlideID,
      baseURL: fileURL?.deletingLastPathComponent()
    )
  }

  private func clampedSlideIndex(_ index: Int?) -> Int? {
    guard let index, document.deck.slides.indices.contains(index) else { return nil }
    return index
  }

  private var selectedSlideBinding: Binding<Slide>? {
    guard let index = effectiveSelectedSlideIndex else { return nil }
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
    guard let selectedSlideID else { return nil }
    return document.deck.slides.firstIndex(where: { $0.id == selectedSlideID })
  }

  private var effectiveSelectedSlideIndex: Int? {
    selectedSlideIndex ?? document.deck.slides.indices.first
  }

  private var effectiveSelectedSlideID: Slide.ID? {
    if let selectedSlideID, document.deck.slides.contains(where: { $0.id == selectedSlideID }) {
      return selectedSlideID
    }
    return document.deck.slides.first?.id
  }

  private func ensureSelection() {
    if effectiveSelectedSlideID != selectedSlideID {
      selectedSlideID = document.deck.slides.first?.id
    }
  }

  private func addSlide() {
    slideCommandActions.addSlide()
  }

  private func showTemplatePicker() {
    isShowingTemplatePicker = true
  }

  private func hideTemplatePicker() {
    isShowingTemplatePicker = false
  }

  private func insertTemplateSlide(_ template: SlideTemplate) {
    slideCommandActions.addSlide(from: template)
    isShowingTemplatePicker = false
  }

  private func applyAssistantChanges(_ changes: [DeckAssistantChange]) {
    guard !changes.isEmpty else { return }

    var deck = document.deck
    var selectedIndexAfterApply: Int?

    for change in changes {
      switch change.operation {
      case .replace(let index):
        guard deck.slides.indices.contains(index) else { continue }
        deck.slides[index].markdown = change.afterMarkdown
        selectedIndexAfterApply = index
      case .insert:
        continue
      }
    }

    let insertions = changes.compactMap { change -> (position: Int, markdown: String)? in
      guard case .insert(let position) = change.operation else { return nil }
      return (position, change.afterMarkdown)
    }
    .sorted { $0.position < $1.position }

    for (offset, insertion) in insertions.enumerated() {
      let insertionIndex = min(max(insertion.position + offset, 0), deck.slides.count)
      deck.slides.insert(Slide(markdown: insertion.markdown), at: insertionIndex)
      selectedIndexAfterApply = insertionIndex
    }

    document.deck = deck

    if let selectedIndexAfterApply, deck.slides.indices.contains(selectedIndexAfterApply) {
      selectedSlideID = deck.slides[selectedIndexAfterApply].id
    } else {
      ensureSelection()
    }
  }

  private func duplicateSlide() {
    slideCommandActions.duplicateSlide()
  }

  private func deleteSlide() {
    var deck = document.deck
    selectedSlideID = deck.deleteSlide(effectiveSelectedSlideID)
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

  private func registerLiveMCPDocument() {
    let documentBinding = Binding(
      get: { document },
      set: { document = $0 }
    )

    LiveMCPDocumentRegistry.shared.register(
      LiveMCPDocumentSession(
        id: liveMCPDocumentID,
        fileURL: { fileURL },
        deck: { documentBinding.wrappedValue.deck },
        setDeck: { deck in
          documentBinding.wrappedValue.deck = deck
          ensureSelection()
        },
        selectedSlideIndex: { selectedSlideIndex },
        selectSlide: { index in
          guard documentBinding.wrappedValue.deck.slides.indices.contains(index) else { return }
          selectedSlideID = documentBinding.wrappedValue.deck.slides[index].id
        },
        present: {
          presentationPresenter.present(
            deck: documentBinding.wrappedValue.deck,
            selectedSlideID: selectedSlideID,
            baseURL: fileURL?.deletingLastPathComponent(),
            sessions: sessionStore
          )
        },
        dismissPresentation: {
          presentationPresenter.dismiss()
        }
      )
    )
  }

  private func unregisterLiveMCPDocument() {
    LiveMCPDocumentRegistry.shared.unregister(liveMCPDocumentID)
  }

  private var rightUtilityMode: DocumentRightUtilityPane {
    get {
      DocumentRightUtilityPane(rawValue: rightUtilityModeRawValue) ?? .preview
    }
    nonmutating set {
      rightUtilityModeRawValue = newValue.rawValue
    }
  }

  private var rightUtilityIdealWidth: CGFloat {
    switch rightUtilityMode {
    case .preview:
      640
    case .assistant:
      460
    }
  }

  private var compactPane: CompactDetailPane {
    get {
      CompactDetailPane(rawValue: compactPaneRawValue) ?? .editor
    }
    nonmutating set {
      compactPaneRawValue = newValue.rawValue
    }
  }

  private var compactPaneBinding: Binding<CompactDetailPane> {
    Binding(
      get: { compactPane },
      set: { compactPane = $0 }
    )
  }

  private var rightUtilityModeBinding: Binding<DocumentRightUtilityPane> {
    Binding(
      get: { rightUtilityMode },
      set: { showRightUtility($0) }
    )
  }

  private var rightUtilityActions: DocumentRightUtilityActions {
    DocumentRightUtilityActions(
      isVisible: isRightUtilityVisible,
      mode: rightUtilityMode,
      togglePreview: { toggleRightUtility(.preview) },
      toggleAssistant: { toggleRightUtility(.assistant) }
    )
  }

  private var slideCommandActions: SlideCommandActions {
    SlideCommandActions(
      document: $document,
      selectedSlideIDString: $selectedSlideIDString,
      presentTemplatePicker: showTemplatePicker
    )
  }

  private func isRightUtilityActive(_ mode: DocumentRightUtilityPane) -> Bool {
    isRightUtilityVisible && rightUtilityMode == mode
  }

  private func toggleRightUtility(_ mode: DocumentRightUtilityPane) {
    if isRightUtilityActive(mode) {
      hideRightUtility()
    } else {
      showRightUtility(mode)
    }
  }

  private func toggleRightUtilityVisibility() {
    isRightUtilityVisible.toggle()
  }

  private func showRightUtility(_ mode: DocumentRightUtilityPane) {
    rightUtilityMode = mode
    isRightUtilityVisible = true
  }

  private func hideRightUtility() {
    isRightUtilityVisible = false
  }
}

private enum CompactDetailPane: String, CaseIterable, Identifiable {
  case editor
  case preview
  case assistant

  var id: String { rawValue }

  var title: String {
    switch self {
    case .editor:
      "Editor"
    case .preview:
      "Preview"
    case .assistant:
      "Assistant"
    }
  }

  var systemImage: String {
    switch self {
    case .editor:
      "pencil"
    case .preview:
      "play.rectangle"
    case .assistant:
      "sparkles"
    }
  }
}
