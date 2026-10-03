import SwiftUI

struct DeckAssistantComposer: View {
    @Binding var goal: String
    @Binding var allowsWebResearch: Bool
    let isRunning: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $goal)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(height: 52)
                    .overlay(alignment: .topLeading) {
                        if goal.isEmpty {
                            Text("What would you like to improve?")
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .padding(.top, 4)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .disabled(isRunning)
                    .accessibilityLabel("Assistant prompt")

                HStack(spacing: 8) {
                    Toggle(isOn: $allowsWebResearch) {
                        Label("Use Web", systemImage: "globe")
                    }
                    .toggleStyle(.checkbox)
                    .labelStyle(.iconOnly)
                    .controlSize(.small)
                    .disabled(isRunning)
                    .help(allowsWebResearch ? "Web research is on. Click to turn it off." : "Allow web research for current facts and citations.")

                    Spacer(minLength: 0)

                    if isRunning {
                        Button(action: onStop) {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(width: 16, height: 16)
                        }
                        .labelStyle(.iconOnly)
                        .controlSize(.regular)
                        .buttonBorderShape(.circle)
                        .codeckNativeButtonStyle()
                        .help("Stop Assistant run")
                    } else {
                        Button(action: onSend) {
                            Label("Send", systemImage: "arrow.up")
                                .frame(width: 16, height: 16)
                        }
                        .labelStyle(.iconOnly)
                        .controlSize(.regular)
                        .buttonBorderShape(.circle)
                        .codeckNativeButtonStyle(prominent: true)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(!canSend)
                        .help("Send to Codex (⌘Return)")
                    }
                }
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}
