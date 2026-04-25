import SwiftUI

struct EditorPaneView: View {
  @Binding var slide: Slide
  @Binding var theme: PresentationTheme
  let onInsertCodexBlock: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      toolbar

      Divider()

      TextEditor(text: $slide.markdown)
        .font(.system(size: 15, design: .monospaced))
        .scrollContentBackground(.hidden)
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor))
    }
  }

  private var toolbar: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        themePicker(width: 150)

        Spacer(minLength: 10)

        insertCodexButton
          .labelStyle(.titleAndIcon)
      }

      HStack(spacing: 8) {
        themePicker(width: 128)

        Spacer(minLength: 8)

        insertCodexButton
          .labelStyle(.iconOnly)
      }
    }
    .padding(12)
  }

  private func themePicker(width: CGFloat) -> some View {
    Picker("Theme", selection: $theme) {
      ForEach(PresentationTheme.allCases) { theme in
        Text(theme.displayName).tag(theme)
      }
    }
    .pickerStyle(.menu)
    .frame(width: width)
  }

  private var insertCodexButton: some View {
    Button(action: onInsertCodexBlock) {
      Label("Insert Codex Session", systemImage: "terminal")
    }
    .help("Insert live Codex session")
  }
}
