import AppKit
import SwiftUI

@main
struct CodeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var liveMCPServer = LiveMCPServerController.shared

    var body: some Scene {
        DocumentGroup(newDocument: PresentationDocument()) { file in
            DocumentWindowView(document: file.$document, fileURL: file.fileURL)
        }
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1200, height: 800)
        .commands {
            PresentationCommands()
        }

        Settings {
            CodeckSettingsView(liveMCPServer: liveMCPServer)
        }
    }
}
