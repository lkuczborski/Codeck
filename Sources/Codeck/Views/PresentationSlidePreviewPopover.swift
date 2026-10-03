import CodeckCore
import CodeckRuntime
import SwiftUI

struct PresentationSlidePreviewPopover: View {
    static let slideSize = CGSize(width: 380, height: 213.75)
    static let contentSize = CGSize(width: 400, height: 233.75)

    let deck: PresentationDeck
    let selectedSlideID: Slide.ID?
    @ObservedObject var sessions: CodexSessionStore
    let baseURL: URL?
    @Binding var skimmedSlideIndex: Int?
    let onHoverChanged: (Bool) -> Void
    let onDetach: (Int?) -> Void

    var selectedSlideIndex: Int? {
        guard let selectedSlideID else { return nil }
        return deck.slides.firstIndex(where: { $0.id == selectedSlideID })
    }

    private var displayedSlideIndex: Int? {
        clampedSlideIndex(skimmedSlideIndex)
            ?? clampedSlideIndex(selectedSlideIndex)
            ?? deck.slides.indices.first
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PresentationSlidePreviewView(
                deck: deck,
                selectedSlideID: selectedSlideID,
                sessions: sessions,
                baseURL: baseURL,
                fallbackSlideIndex: nil,
                skimmedSlideIndex: $skimmedSlideIndex,
                isChromeVisible: true
            )

            Button {
                onDetach(displayedSlideIndex)
            } label: {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12, weight: .bold))
            }
            .controlSize(.small)
            .buttonBorderShape(.circle)
            .codeckNativeButtonStyle()
            .help("Pin preview")
            .padding(8)
        }
        .frame(width: Self.slideSize.width, height: Self.slideSize.height)
        .padding(10)
        .onHover(perform: onHoverChanged)
        .onDisappear {
            onHoverChanged(false)
            skimmedSlideIndex = nil
        }
    }

    private func clampedSlideIndex(_ index: Int?) -> Int? {
        guard let index, deck.slides.indices.contains(index) else { return nil }
        return index
    }
}
