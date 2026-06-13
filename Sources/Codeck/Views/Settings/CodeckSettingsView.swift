import SwiftUI

struct CodeckSettingsView: View {
    @ObservedObject var liveMCPServer: LiveMCPServerController
    @AppStorage(LiveMCPSettings.enabledStorageKey) private var isLiveMCPServerEnabled = false

    var body: some View {
        Form {
            Section("MCP") {
                Toggle("Live Bridge", isOn: $isLiveMCPServerEnabled)
                    .onChange(of: isLiveMCPServerEnabled) { _, isEnabled in
                        liveMCPServer.setEnabled(isEnabled)
                    }

                LabeledContent("Status") {
                    if liveMCPServer.errorMessage == nil {
                        Text(statusText)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(statusText)
                            .foregroundStyle(.red)
                    }
                }

                LabeledContent("Endpoint") {
                    Text(LiveMCPSettings.endpointURL.absoluteString)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(20)
        .onAppear {
            liveMCPServer.synchronizeWithPreferences()
        }
    }

    private var statusText: String {
        if let errorMessage = liveMCPServer.errorMessage {
            return errorMessage
        }
        return liveMCPServer.isRunning ? "Running" : "Stopped"
    }
}
