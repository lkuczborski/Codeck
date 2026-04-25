import SwiftUI

struct EditorPaneView: View {
  @Binding var slide: Slide
  @Binding var settings: PresentationSettings
  let onInsertCodexBlock: () -> Void
  @State private var showsDeckSettings = false

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

        deckSettingsButton
          .labelStyle(.titleAndIcon)

        insertCodexButton
          .labelStyle(.titleAndIcon)
      }

      HStack(spacing: 8) {
        themePicker(width: 128)

        Spacer(minLength: 8)

        deckSettingsButton
          .labelStyle(.iconOnly)

        insertCodexButton
          .labelStyle(.iconOnly)
      }
    }
    .padding(12)
  }

  private func themePicker(width: CGFloat) -> some View {
    Picker("Theme", selection: $settings.theme) {
      ForEach(PresentationTheme.allCases) { theme in
        Text(theme.displayName).tag(theme)
      }
    }
    .pickerStyle(.menu)
    .frame(width: width)
  }

  private var deckSettingsButton: some View {
    Button {
      showsDeckSettings.toggle()
    } label: {
      Label("Deck Settings", systemImage: "slider.horizontal.3")
    }
    .help("Edit deck-level Codex settings")
    .popover(isPresented: $showsDeckSettings, arrowEdge: .bottom) {
      DeckSettingsPopover(settings: $settings)
    }
  }

  private var insertCodexButton: some View {
    Button(action: onInsertCodexBlock) {
      Label("Insert Codex Session", systemImage: "terminal")
    }
    .help("Insert live Codex session")
  }
}

private struct DeckSettingsPopover: View {
  @Binding var settings: PresentationSettings

  var body: some View {
    Form {
      Picker("Theme", selection: $settings.theme) {
        ForEach(PresentationTheme.allCases) { theme in
          Text(theme.displayName).tag(theme)
        }
      }

      TextField("Model", text: optionalTextBinding(\.model))
        .textFieldStyle(.roundedBorder)

      Picker("Reasoning", selection: reasoningBinding) {
        Text("System Default").tag("")
        ForEach(CodexReasoningEffort.allCases) { effort in
          Text(effort.displayName).tag(effort.rawValue)
        }
      }

      Picker("Sandbox", selection: $settings.codex.sandbox) {
        Text("Read Only").tag("read-only")
        Text("Workspace Write").tag("workspace-write")
        Text("Danger Full Access").tag("danger-full-access")
      }

      TextField("Profile", text: optionalTextBinding(\.profile))
        .textFieldStyle(.roundedBorder)
    }
    .formStyle(.grouped)
    .padding(16)
    .frame(width: 340)
  }

  private var reasoningBinding: Binding<String> {
    Binding(
      get: { settings.codex.reasoning?.rawValue ?? "" },
      set: { value in
        settings.codex.reasoning = value.isEmpty ? nil : CodexReasoningEffort(rawValue: value)
      }
    )
  }

  private func optionalTextBinding(_ keyPath: WritableKeyPath<DeckCodexSettings, String?>) -> Binding<String> {
    Binding(
      get: { settings.codex[keyPath: keyPath] ?? "" },
      set: { value in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.codex[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
      }
    )
  }
}
