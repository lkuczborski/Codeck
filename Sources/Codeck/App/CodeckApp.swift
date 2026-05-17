import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    AppAppearanceController.apply(rawValue: UserDefaults.standard.string(forKey: AppAppearanceMode.storageKey))
    LiveMCPServerController.shared.synchronizeWithPreferences()
    NSApp.activate(ignoringOtherApps: true)
  }
}

@main
struct CodeckApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var liveMCPServer = LiveMCPServerController.shared

  var body: some Scene {
    DocumentGroup(newDocument: PresentationDocument()) { file in
      DocumentWindowView(document: file.$document, fileURL: file.fileURL)
    }
    .commands {
      PresentationCommands()
    }

    Settings {
      CodeckSettingsView(liveMCPServer: liveMCPServer)
    }
  }
}
