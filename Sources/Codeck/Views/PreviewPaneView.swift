import SwiftUI

struct PreviewPaneView: View {
  let slide: Slide
  let theme: PresentationTheme
  @ObservedObject var sessions: CodexSessionStore
  let baseURL: URL?
  let onRunBlock: (CodexBlock) -> Void
  let onRunAll: ([CodexBlock]) -> Void

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
    MarkdownWebView(html: html, baseURL: baseURL, onAction: handleWebAction)
    .background(.ultraThinMaterial)
  }

  private func handleWebAction(_ action: MarkdownWebAction) {
    switch action {
    case .runCodex(let id):
      if let block = codexBlocks.first(where: { $0.id == id }) {
        onRunBlock(block)
      }
    case .stopCodex(let id):
      sessions.stop(id)
    case .runAllCodex:
      onRunAll(codexBlocks)
    }
  }
}
