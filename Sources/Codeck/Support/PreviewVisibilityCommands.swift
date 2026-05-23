import CodeckCore
import SwiftUI

struct PresentationCommands: Commands {
  @FocusedValue(\.rightUtilityActions) private var rightUtilityActions
  @FocusedValue(\.slideCommandActions) private var slideCommandActions

  var body: some Commands {
    CommandMenu("Presentation") {
      Section("Slides") {
        Button("New Slide") {
          slideCommandActions?.addSlide()
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        .disabled(slideCommandActions == nil)

        Button("New Slide from Template...") {
          slideCommandActions?.showTemplatePicker()
        }
        .keyboardShortcut("n", modifiers: [.command, .option, .shift])
        .disabled(slideCommandActions?.canShowTemplatePicker != true)

        Button("Duplicate Slide") {
          slideCommandActions?.duplicateSlide()
        }
        .keyboardShortcut("d", modifiers: [.command])
        .disabled(slideCommandActions?.canDuplicateSlide != true)
      }

      Divider()

      Button(rightUtilityActions?.isPreviewActive == true ? "Hide Preview" : "Show Preview") {
        rightUtilityActions?.togglePreview()
      }
      .keyboardShortcut("0", modifiers: [.command, .option])
      .disabled(rightUtilityActions == nil)

      Button(rightUtilityActions?.isAssistantActive == true ? "Hide Deck Assistant" : "Show Deck Assistant") {
        rightUtilityActions?.toggleAssistant()
      }
      .keyboardShortcut("1", modifiers: [.command, .option])
      .disabled(rightUtilityActions == nil)
    }
  }
}

enum DocumentRightUtilityPane: String, CaseIterable, Identifiable {
  case preview
  case assistant

  var id: String { rawValue }

  var title: String {
    switch self {
    case .preview:
      "Preview"
    case .assistant:
      "Assistant"
    }
  }

  var systemImage: String {
    switch self {
    case .preview:
      "play.rectangle"
    case .assistant:
      "sparkles"
    }
  }
}

struct DocumentRightUtilityActions {
  let isVisible: Bool
  let mode: DocumentRightUtilityPane
  let togglePreview: () -> Void
  let toggleAssistant: () -> Void

  var isPreviewActive: Bool {
    isVisible && mode == .preview
  }

  var isAssistantActive: Bool {
    isVisible && mode == .assistant
  }
}

struct SlideCommandActions {
  let document: Binding<PresentationDocument>
  let selectedSlideIDString: Binding<String?>
  var presentTemplatePicker: (() -> Void)?

  var canDuplicateSlide: Bool {
    resolvedSelectedSlideID(in: document.wrappedValue.deck) != nil
  }

  var canShowTemplatePicker: Bool {
    presentTemplatePicker != nil
  }

  func addSlide(markdown: String = PresentationDeck.defaultSlideMarkdown) {
    var deck = document.wrappedValue.deck
    let newID = deck.addSlide(after: resolvedSelectedSlideID(in: deck), markdown: markdown)
    document.wrappedValue.deck = deck
    setSelectedSlideID(newID)
  }

  func addSlide(from template: SlideTemplate) {
    addSlide(markdown: template.markdown)
  }

  func duplicateSlide() {
    var deck = document.wrappedValue.deck
    guard let newID = deck.duplicateSlide(resolvedSelectedSlideID(in: deck)) else {
      return
    }

    document.wrappedValue.deck = deck
    setSelectedSlideID(newID)
  }

  func showTemplatePicker() {
    presentTemplatePicker?()
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

private struct RightUtilityActionsFocusedKey: FocusedValueKey {
  typealias Value = DocumentRightUtilityActions
}

extension FocusedValues {
  var slideCommandActions: SlideCommandActions? {
    get { self[SlideCommandActionsFocusedKey.self] }
    set { self[SlideCommandActionsFocusedKey.self] = newValue }
  }

  var rightUtilityActions: DocumentRightUtilityActions? {
    get { self[RightUtilityActionsFocusedKey.self] }
    set { self[RightUtilityActionsFocusedKey.self] = newValue }
  }
}
