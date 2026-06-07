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
