import AppKit
import CodeckCore
import SwiftUI

struct PresentationPreviewWindowContent: View {
    @ObservedObject var state: PresentationPreviewWindowState
    @ObservedObject var sessions: CodexSessionStore
    let onClose: () -> Void

    @State private var skimmedSlideIndex: Int?
    @State private var isHovered = false

    var body: some View {
        ZStack {
            PresentationSlidePreviewView(
                deck: state.deck,
                selectedSlideID: state.selectedSlideID,
                sessions: sessions,
                baseURL: state.baseURL,
                fallbackSlideIndex: state.fallbackSlideIndex,
                skimmedSlideIndex: $skimmedSlideIndex,
                isChromeVisible: isHovered,
                handlesScrubbing: false,
                showsShadow: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PresentationPreviewWindowInteractionLayer(
                slideCount: state.deck.slides.count,
                skimmedSlideIndex: $skimmedSlideIndex,
                isHovered: $isHovered
            )

            GeometryReader { proxy in
                let slideRect = slideRect(in: proxy.size)

                closeButton
                    .opacity(isHovered ? 1 : 0)
                    .position(x: slideRect.maxX - 20, y: slideRect.minY + 20)
                    .animation(.easeOut(duration: 0.12), value: isHovered)
            }
            .allowsHitTesting(isHovered)
        }
        .onHover { hovering in
            isHovered = hovering
            if !hovering {
                skimmedSlideIndex = nil
            }
        }
        .onChange(of: state.deck.slides) { _, _ in
            skimmedSlideIndex = state.clampedSlideIndex(skimmedSlideIndex)
            state.fallbackSlideIndex = state.clampedSlideIndex(state.fallbackSlideIndex)
        }
        .onChange(of: state.selectedSlideID) { _, _ in
            skimmedSlideIndex = nil
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.black.opacity(0.62), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func slideRect(in size: CGSize) -> CGRect {
        let aspectRatio = 16.0 / 9.0
        guard size.width > 0, size.height > 0 else { return .zero }

        let availableAspectRatio = size.width / size.height
        if availableAspectRatio > aspectRatio {
            let width = size.height * aspectRatio
            return CGRect(
                x: (size.width - width) / 2,
                y: 0,
                width: width,
                height: size.height
            )
        }

        let height = size.width / aspectRatio
        return CGRect(
            x: 0,
            y: (size.height - height) / 2,
            width: size.width,
            height: height
        )
    }
}
