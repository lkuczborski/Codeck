import CodeckCore
import CodeckRuntime
import SwiftUI

struct PreviewPaneView: View {
    let slide: Slide
    let theme: PresentationTheme
    @ObservedObject var sessions: CodexSessionStore
    let baseURL: URL?
    var showsControls = true
    var isFramed = true
    let onRunBlock: (CodexBlock) -> Void
    let onRunAll: ([CodexBlock]) -> Void

    private var codexBlocks: [CodexBlock] {
        slide.codexBlocks
    }

    private var html: String {
        MarkdownRenderer.presentationHTMLDocument(
            for: slide,
            theme: theme,
            codexOutputs: sessions.outputs,
            showsControls: showsControls
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = isFramed ? 20 : 0
            let width = max(0, min(proxy.size.width - inset * 2, (proxy.size.height - inset * 2) * 16.0 / 9.0))
            let height = width * 9.0 / 16.0
            MarkdownWebView(html: html, baseURL: baseURL, onAction: handleWebAction)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: isFramed ? 10 : 0))
                .overlay {
                    if isFramed {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                    }
                }
                .shadow(color: .black.opacity(isFramed ? 0.16 : 0), radius: 12, y: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isFramed ? .center : .top)
                .transaction { $0.animation = nil }
        }
        .codeckWorkspaceBackground()
    }

    private func handleWebAction(_ action: MarkdownWebAction) {
        switch action {
        case let .runCodex(id):
            if let block = codexBlocks.first(where: { $0.id == id }) {
                onRunBlock(block)
            }
        case let .stopCodex(id):
            sessions.stop(id)
        case .runAllCodex:
            onRunAll(codexBlocks)
        }
    }
}
