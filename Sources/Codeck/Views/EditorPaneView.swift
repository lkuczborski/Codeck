import SwiftUI

struct EditorPaneView: View {
  @Binding var slide: Slide
  @Binding var theme: PresentationTheme
  let onInsertCodexBlock: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Picker("Theme", selection: $theme) {
          ForEach(PresentationTheme.allCases) { theme in
            Text(theme.displayName).tag(theme)
          }
        }
        .pickerStyle(.menu)
        .frame(width: 150)

        Spacer()

        Button(action: onInsertCodexBlock) {
          Label("Insert Codex Session", systemImage: "terminal")
        }
        .help("Insert live Codex session")
      }
      .padding(12)

      Divider()

      TextEditor(text: $slide.markdown)
        .font(.system(size: 15, design: .monospaced))
        .scrollContentBackground(.hidden)
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor))
    }
  }
}
