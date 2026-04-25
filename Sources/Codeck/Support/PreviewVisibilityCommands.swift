import SwiftUI

struct PreviewVisibilityCommands: Commands {
  @FocusedValue(\.previewVisibility) private var previewVisibility

  var body: some Commands {
    CommandMenu("Presentation") {
      Button(previewVisibility?.wrappedValue == true ? "Hide Preview" : "Show Preview") {
        previewVisibility?.wrappedValue.toggle()
      }
      .keyboardShortcut("0", modifiers: [.command, .option])
      .disabled(previewVisibility == nil)
    }
  }
}

private struct PreviewVisibilityFocusedKey: FocusedValueKey {
  typealias Value = Binding<Bool>
}

extension FocusedValues {
  var previewVisibility: Binding<Bool>? {
    get { self[PreviewVisibilityFocusedKey.self] }
    set { self[PreviewVisibilityFocusedKey.self] = newValue }
  }
}
