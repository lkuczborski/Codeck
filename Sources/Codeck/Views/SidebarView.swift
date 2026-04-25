import SwiftUI

struct SidebarView: View {
  @Binding var deck: PresentationDeck
  @Binding var selection: Slide.ID?

  var body: some View {
    VStack(spacing: 0) {
      List(selection: $selection) {
        ForEach(Array(deck.slides.enumerated()), id: \.element.id) { index, slide in
          SidebarSlideRow(index: index + 1, slide: slide)
            .tag(slide.id)
        }
        .onMove(perform: moveSlides)
      }
      .listStyle(.sidebar)

      Divider()

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

        Spacer()

        Button(role: .destructive, action: deleteSlide) {
          Label("Delete Slide", systemImage: "trash")
        }
        .help("Delete slide")
        .disabled(deck.slides.count <= 1)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .padding(10)
    }
    .navigationTitle("Slides")
  }

  private func addSlide() {
    selection = deck.addSlide(after: selection)
  }

  private func duplicateSlide() {
    if let newID = deck.duplicateSlide(selection) {
      selection = newID
    }
  }

  private func deleteSlide() {
    selection = deck.deleteSlide(selection)
  }

  private func moveSlides(from source: IndexSet, to destination: Int) {
    deck.slides.move(fromOffsets: source, toOffset: destination)
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
