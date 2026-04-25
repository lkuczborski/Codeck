import SwiftUI

struct DocumentWindowView: View {
  @Binding var document: PresentationDocument
  let fileURL: URL?

  @StateObject private var sessionStore = CodexSessionStore()
  @SceneStorage("selectedSlideID") private var selectedSlideIDString: String?
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
      .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
    } detail: {
      detail
    }
    .frame(minWidth: 1100, minHeight: 720)
    .onAppear(perform: ensureSelection)
    .onChange(of: document.deck.slides) { _, _ in
      ensureSelection()
    }
  }

  @ViewBuilder
  private var detail: some View {
    if let slide = selectedSlideBinding {
      HSplitView {
        EditorPaneView(
          slide: slide,
          theme: $document.deck.theme,
          onInsertCodexBlock: {
            document.deck.insertCodexBlock(into: selectedSlideID)
          }
        )
        .frame(minWidth: 420, idealWidth: 520)

        PreviewPaneView(
          slide: slide.wrappedValue,
          theme: document.deck.theme,
          sessions: sessionStore,
          baseURL: fileURL?.deletingLastPathComponent(),
          onRunBlock: { block in
            sessionStore.run(block, workingDirectory: fileURL?.deletingLastPathComponent())
          },
          onRunAll: { blocks in
            sessionStore.runAll(blocks, workingDirectory: fileURL?.deletingLastPathComponent())
          },
          onStopAll: {
            sessionStore.stopAll()
          }
        )
        .frame(minWidth: 460, idealWidth: 640)
      }
    } else {
      ContentUnavailableView("No Slide", systemImage: "rectangle.stack", description: Text("Create a slide to start editing."))
    }
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
}
