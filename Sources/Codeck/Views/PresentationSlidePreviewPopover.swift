import CodeckCore
import SwiftUI

struct PresentationSlidePreviewPopover: View {
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
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(.black.opacity(0.62), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Pin preview")
            .padding(8)
        }
        .frame(width: 380)
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
