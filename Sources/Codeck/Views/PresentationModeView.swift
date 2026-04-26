import SwiftUI

struct PresentationModeView: View {
  @ObservedObject var playbackState: PresentationPlaybackState
  @ObservedObject var sessions: CodexSessionStore
  let baseURL: URL?

  private var html: String {
    guard let slide = playbackState.currentSlide else {
      return MarkdownRenderer.htmlDocument(
        for: Slide(markdown: "# No Slides"),
        theme: playbackState.deck.theme,
        codexOutputs: sessions.outputs
      )
    }

    return MarkdownRenderer.htmlDocument(
      for: slide,
      theme: playbackState.deck.theme,
      codexOutputs: sessions.outputs
    )
  }

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Color.black
        .ignoresSafeArea()

      MarkdownWebView(html: html, baseURL: baseURL, onAction: handleWebAction)
        .ignoresSafeArea()

      Text("\(playbackState.currentSlideNumber) / \(playbackState.slideCount)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.white.opacity(0.78))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.42), in: Capsule())
        .padding(18)
    }
  }

  private func handleWebAction(_ action: MarkdownWebAction) {
    let blocks = playbackState.currentSlide?.codexBlocks ?? []

    switch action {
    case .runCodex(let id):
      if let block = blocks.first(where: { $0.id == id }) {
        sessions.run(block, settings: playbackState.deck.settings.codex, workingDirectory: baseURL)
      }
    case .stopCodex(let id):
      sessions.stop(id)
    case .runAllCodex:
      sessions.runAll(blocks, settings: playbackState.deck.settings.codex, workingDirectory: baseURL)
    }
  }
}
