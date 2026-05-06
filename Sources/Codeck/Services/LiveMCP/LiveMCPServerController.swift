import Combine
import Foundation

@MainActor
final class LiveMCPServerController: ObservableObject {
  static let shared = LiveMCPServerController()

  @Published private(set) var isRunning = false
  @Published private(set) var errorMessage: String?

  private var server: LiveMCPHTTPServer?

  private init() {}

  func synchronizeWithPreferences() {
    setEnabled(UserDefaults.standard.bool(forKey: LiveMCPSettings.enabledStorageKey))
  }

  func setEnabled(_ isEnabled: Bool) {
    if isEnabled {
      start()
    } else {
      stop()
    }
  }

  func start() {
    guard !isRunning else { return }

    do {
      let server = LiveMCPHTTPServer()
      try server.start()
      self.server = server
      isRunning = true
      errorMessage = nil
    } catch {
      isRunning = false
      errorMessage = error.localizedDescription
    }
  }

  func stop() {
    server?.stop()
    server = nil
    isRunning = false
    errorMessage = nil
  }
}
