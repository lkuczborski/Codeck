import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}

@main
struct CodeckApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    DocumentGroup(newDocument: PresentationDocument()) { file in
      DocumentWindowView(document: file.$document, fileURL: file.fileURL)
    }
    .commands {
      PreviewVisibilityCommands()
    }
  }
}
