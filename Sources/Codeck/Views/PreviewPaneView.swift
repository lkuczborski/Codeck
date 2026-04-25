import SwiftUI

struct PreviewPaneView: View {
  let slide: Slide
  let theme: PresentationTheme
  @ObservedObject var sessions: CodexSessionStore
  let baseURL: URL?
  let onRunBlock: (CodexBlock) -> Void
  let onRunAll: ([CodexBlock]) -> Void
  let onStopAll: () -> Void

  private var codexBlocks: [CodexBlock] {
    slide.codexBlocks
  }

  private var html: String {
    MarkdownRenderer.htmlDocument(
      for: slide,
      theme: theme,
      codexOutputs: sessions.outputs
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Text("Preview")
          .font(.headline)

        Spacer()

        Menu {
          ForEach(codexBlocks) { block in
            Button(block.title) {
              onRunBlock(block)
            }
          }
        } label: {
          Label("Run Session", systemImage: "play")
        }
        .disabled(codexBlocks.isEmpty)
        .help("Run one Codex session")

        Button {
          onRunAll(codexBlocks)
        } label: {
          Label("Run All", systemImage: "play.circle")
        }
        .disabled(codexBlocks.isEmpty)
        .help("Run all Codex sessions on this slide")

        Button(role: .cancel, action: onStopAll) {
          Label("Stop", systemImage: "stop.circle")
        }
        .disabled(sessions.runningIDs.isEmpty)
        .help("Stop running Codex sessions")
      }
      .labelStyle(.titleAndIcon)
      .padding(12)

      Divider()

      MarkdownWebView(html: html, baseURL: baseURL)
    }
    .background(Color(nsColor: .windowBackgroundColor))
  }
}
