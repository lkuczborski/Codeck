import CodeckCore
import SwiftUI

struct SidebarView: View {
    let deck: PresentationDeck
    @Binding var selection: Slide.ID?
    let onAddSlide: () -> Void
    let onAddTemplateSlide: () -> Void
    let onDuplicateSlide: () -> Void
    let onDeleteSlide: () -> Void
    let onMoveSlides: (IndexSet, Int) -> Void
    @State private var isConfirmingDelete = false

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $selection) {
                ForEach(Array(deck.slides.enumerated()), id: \.element.id) { index, slide in
                    SidebarSlideRow(index: index + 1, slide: slide)
                        .id(slide.id)
                        .tag(slide.id)
                }
                .onMove(perform: moveSlides)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .codeckNativeBottomBar {
                sidebarFooter
            }
            .navigationTitle("Slides")
            .onDeleteCommand {
                confirmDeleteSlide()
            }
            .alert("Delete Slide?", isPresented: $isConfirmingDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSlide()
                }
            } message: {
                Text("This will remove the current slide from the deck.")
            }
            .onAppear {
                scrollToSelectedSlide(with: proxy, animated: false)
            }
            .onChange(of: selection) { _, _ in
                scrollToSelectedSlide(with: proxy, animated: true)
            }
            .onChange(of: deck.slides.map(\.id)) { _, _ in
                scrollToSelectedSlide(with: proxy, animated: true)
            }
        }
    }

    private var sidebarFooter: some View {
        slideActionButtons
            .padding(8)
            .codeckNativeControlBar()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    private var slideActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: addSlide) {
                Label("Add Slide", systemImage: "plus")
            }
            .help("Add slide")

            Button(action: addTemplateSlide) {
                Label("Add Slide from Template", systemImage: "square.grid.2x2")
            }
            .help("Add slide from template")

            Button(action: duplicateSlide) {
                Label("Duplicate Slide", systemImage: "doc.on.doc")
            }
            .help("Duplicate slide")
            .disabled(selection == nil)

            Spacer(minLength: 8)

            Button(role: .destructive, action: confirmDeleteSlide) {
                Label("Delete Slide", systemImage: "trash")
            }
            .help("Delete slide")
            .disabled(!canDeleteSelectedSlide)
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .controlSize(.regular)
        .frame(maxWidth: .infinity)
    }

    private func addSlide() {
        onAddSlide()
    }

    private func addTemplateSlide() {
        onAddTemplateSlide()
    }

    private func duplicateSlide() {
        onDuplicateSlide()
    }

    private var canDeleteSelectedSlide: Bool {
        selection != nil && deck.slides.count > 1
    }

    private func confirmDeleteSlide() {
        guard canDeleteSelectedSlide else { return }
        isConfirmingDelete = true
    }

    private func deleteSlide() {
        onDeleteSlide()
    }

    private func moveSlides(from source: IndexSet, to destination: Int) {
        onMoveSlides(source, destination)
    }

    private func scrollToSelectedSlide(with proxy: ScrollViewProxy, animated: Bool) {
        guard let selection else { return }

        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.16)) {
                    proxy.scrollTo(selection, anchor: .center)
                }
            } else {
                proxy.scrollTo(selection, anchor: .center)
            }
        }
    }
}
