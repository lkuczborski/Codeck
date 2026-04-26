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

      MarkdownWebView(html: html, baseURL: baseURL)
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
}
