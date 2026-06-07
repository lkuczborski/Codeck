import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_: Notification) {
    NSApp.setActivationPolicy(.regular)
    AppAppearanceController.apply(rawValue: UserDefaults.standard.string(forKey: AppAppearanceMode.storageKey))
    LiveMCPServerController.shared.synchronizeWithPreferences()
    NSApp.activate(ignoringOtherApps: true)
  }
}
