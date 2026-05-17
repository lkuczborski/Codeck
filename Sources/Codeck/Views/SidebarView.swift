import CodeckCore
import SwiftUI

struct SidebarView: View {
  let deck: PresentationDeck
  @Binding var selection: Slide.ID?
  let onAddSlide: () -> Void
  let onDuplicateSlide: () -> Void
  let onDeleteSlide: () -> Void
  let onMoveSlides: (IndexSet, Int) -> Void

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
      .safeAreaInset(edge: .bottom, spacing: 0) {
        sidebarFooter
      }
      .navigationTitle("Slides")
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

  @ViewBuilder
  private var sidebarFooter: some View {
    if #available(macOS 26.0, *) {
      GlassEffectContainer {
        slideActionButtons
          .buttonStyle(.glass)
      }
    } else {
      slideActionButtons
        .buttonStyle(.borderless)
        .codeckGlassSurface(cornerRadius: 22)
    }
  }

  private var slideActionButtons: some View {
    HStack(spacing: 8) {
      Button(action: addSlide) {
        Label("Add Slide", systemImage: "plus")
      }
      .help("Add slide")

      Button(action: duplicateSlide) {
        Label("Duplicate Slide", systemImage: "doc.on.doc")
      }
      .help("Duplicate slide")
      .disabled(selection == nil)

      Spacer(minLength: 10)

      Button(role: .destructive, action: deleteSlide) {
        Label("Delete Slide", systemImage: "trash")
      }
      .help("Delete slide")
      .disabled(deck.slides.count <= 1)
    }
    .labelStyle(.iconOnly)
    .buttonBorderShape(.circle)
    .controlSize(.small)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private func addSlide() {
    onAddSlide()
  }

  private func duplicateSlide() {
    onDuplicateSlide()
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

private struct SidebarSlideRow: View {
  let index: Int
  let slide: Slide

  var body: some View {
    HStack(spacing: 10) {
      Text("\(index)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 24, alignment: .trailing)

      VStack(alignment: .leading, spacing: 2) {
        Text(slide.title)
          .lineLimit(1)

        Text(slide.summary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.vertical, 3)
  }
}
