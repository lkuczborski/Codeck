import CodeckCore
import SwiftUI

struct PresentationSlidePreviewView: View {
    let deck: PresentationDeck
    let selectedSlideID: Slide.ID?
    @ObservedObject var sessions: CodexSessionStore
    let baseURL: URL?
    let fallbackSlideIndex: Int?
    @Binding var skimmedSlideIndex: Int?
    var showsCloseButton = false
    var isChromeVisible = false
    var handlesScrubbing = true
    var showsShadow = true
    var onClose: (() -> Void)?

    private var selectedSlideIndex: Int? {
        guard let selectedSlideID else { return nil }
        return deck.slides.firstIndex(where: { $0.id == selectedSlideID })
    }

    private var displayedSlideIndex: Int? {
        clampedSlideIndex(skimmedSlideIndex)
            ?? clampedSlideIndex(fallbackSlideIndex)
            ?? clampedSlideIndex(selectedSlideIndex)
            ?? deck.slides.indices.first
    }

    private var displayedSlide: Slide? {
        guard let displayedSlideIndex else { return nil }
        return deck.slides[displayedSlideIndex]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                previewContent

                if handlesScrubbing {
                    pointerScrubLayer(in: proxy.size)
                }

                if showsCloseButton, let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(.black.opacity(0.62), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isChromeVisible ? 1 : 0)
                    .padding(8)
                    .animation(.easeOut(duration: 0.12), value: isChromeVisible)
                }

                if isChromeVisible, let displayedSlideIndex, deck.slides.count > 1 {
                    slideCounter(displayedSlideIndex)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: showsShadow ? .black.opacity(0.24) : .clear, radius: showsShadow ? 22 : 0, y: showsShadow ? 12 : 0)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
    }

    @ViewBuilder
    private var previewContent: some View {
        if let displayedSlide {
            PreviewPaneView(
                slide: displayedSlide,
                theme: deck.theme,
                sessions: sessions,
                baseURL: baseURL,
                displayMode: .scaledToFitWidth,
                onRunBlock: { _ in },
                onRunAll: { _ in }
            )
            .allowsHitTesting(false)
        } else {
            ZStack {
                Color.black.opacity(0.86)

                Label("No Slides", systemImage: "rectangle.stack")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.84))
            }
        }
    }

    private func pointerScrubLayer(in size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case let .active(point):
                    updateSkimmedSlideIndex(point: point, size: size)
                case .ended:
                    skimmedSlideIndex = nil
                }
            }
    }

    private func slideCounter(_ displayedSlideIndex: Int) -> some View {
        Text("\(displayedSlideIndex + 1) / \(deck.slides.count)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.5), in: Capsule())
            .padding(8)
    }

    private func updateSkimmedSlideIndex(point: CGPoint, size: CGSize) {
        guard deck.slides.count > 1, size.width > 0 else {
            skimmedSlideIndex = nil
            return
        }

        let clampedX = min(max(point.x, 0), size.width)
        let rawIndex = Int((clampedX / size.width) * CGFloat(deck.slides.count))
        skimmedSlideIndex = min(max(rawIndex, 0), deck.slides.count - 1)
    }

    private func clampedSlideIndex(_ index: Int?) -> Int? {
        guard let index, deck.slides.indices.contains(index) else { return nil }
        return index
    }
}
