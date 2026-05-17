import SwiftUI

struct PresentationCommands: Commands {
  @FocusedValue(\.previewVisibility) private var previewVisibility
  @FocusedValue(\.slideCommandActions) private var slideCommandActions

  var body: some Commands {
    CommandMenu("Presentation") {
      Section("Slides") {
        Button("New Slide") {
          slideCommandActions?.addSlide()
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        .disabled(slideCommandActions == nil)

        Button("Duplicate Slide") {
          slideCommandActions?.duplicateSlide()
        }
        .keyboardShortcut("d", modifiers: [.command])
        .disabled(slideCommandActions?.canDuplicateSlide != true)
      }

      Divider()

      Button(previewVisibility?.wrappedValue == true ? "Hide Preview" : "Show Preview") {
        previewVisibility?.wrappedValue.toggle()
      }
      .keyboardShortcut("0", modifiers: [.command, .option])
      .disabled(previewVisibility == nil)
    }
  }
}

struct SlideCommandActions {
  let document: Binding<PresentationDocument>
  let selectedSlideIDString: Binding<String?>

  var canDuplicateSlide: Bool {
    resolvedSelectedSlideID(in: document.wrappedValue.deck) != nil
  }

  func addSlide() {
    var deck = document.wrappedValue.deck
    let newID = deck.addSlide(after: resolvedSelectedSlideID(in: deck))
    document.wrappedValue.deck = deck
    setSelectedSlideID(newID)
  }

  func duplicateSlide() {
    var deck = document.wrappedValue.deck
    guard let newID = deck.duplicateSlide(resolvedSelectedSlideID(in: deck)) else {
      return
    }

    document.wrappedValue.deck = deck
    setSelectedSlideID(newID)
  }

  private var selectedSlideID: Slide.ID? {
    selectedSlideIDString.wrappedValue.flatMap(UUID.init(uuidString:))
  }

  private func resolvedSelectedSlideID(in deck: PresentationDeck) -> Slide.ID? {
    if let selectedSlideID, deck.slides.contains(where: { $0.id == selectedSlideID }) {
      return selectedSlideID
    }

    return deck.slides.first?.id
  }

  private func setSelectedSlideID(_ id: Slide.ID?) {
    selectedSlideIDString.wrappedValue = id?.uuidString
  }
}

private struct SlideCommandActionsFocusedKey: FocusedValueKey {
  typealias Value = SlideCommandActions
}

private struct PreviewVisibilityFocusedKey: FocusedValueKey {
  typealias Value = Binding<Bool>
}

extension FocusedValues {
  var slideCommandActions: SlideCommandActions? {
    get { self[SlideCommandActionsFocusedKey.self] }
    set { self[SlideCommandActionsFocusedKey.self] = newValue }
  }

  var previewVisibility: Binding<Bool>? {
    get { self[PreviewVisibilityFocusedKey.self] }
    set { self[PreviewVisibilityFocusedKey.self] = newValue }
  }
}
