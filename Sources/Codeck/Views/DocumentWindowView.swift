import SwiftUI

struct DocumentWindowView: View {
  @Binding var document: PresentationDocument
  let fileURL: URL?

  @StateObject private var sessionStore = CodexSessionStore()
  @StateObject private var presentationPresenter = PresentationPresenter()
  @SceneStorage("selectedSlideID") private var selectedSlideIDString: String?
  @SceneStorage("isPreviewVisible") private var isPreviewVisible = true
  @SceneStorage("compactDetailPane") private var compactPaneRawValue = "editor"
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  private var selectedSlideID: Slide.ID? {
    get {
      selectedSlideIDString.flatMap(UUID.init(uuidString:))
    }
    nonmutating set {
      selectedSlideIDString = newValue?.uuidString
    }
  }

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      SidebarView(
        deck: $document.deck,
        selection: Binding(
          get: { selectedSlideID },
          set: { selectedSlideID = $0 }
        )
      )
      .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    } detail: {
      detail
    }
    .frame(minWidth: 680, minHeight: 500)
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
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

        Button {
          isPreviewVisible.toggle()
        } label: {
          Label(isPreviewVisible ? "Hide Preview" : "Show Preview", systemImage: "sidebar.right")
        }
        .help(isPreviewVisible ? "Hide preview" : "Show preview")
      }
    }
    .focusedValue(\.previewVisibility, $isPreviewVisible)
    .onAppear(perform: ensureSelection)
    .onChange(of: document.deck.slides) { _, _ in
      ensureSelection()
    }
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
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

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
      onInsertCodexBlock: {
        document.deck.insertCodexBlock(into: selectedSlideID)
      }
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
    return Binding(
      get: { document.deck.slides[index] },
      set: { document.deck.slides[index] = $0 }
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
