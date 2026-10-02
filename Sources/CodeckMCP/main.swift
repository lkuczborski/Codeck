import AppKit

/// stdin remains serial on a background thread; AppKit panels and WKWebView need
/// a live main run loop. The helper stays out of the Dock until UI is requested.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let server = CodeckMCPServer()
DispatchQueue.global(qos: .userInitiated).async {
    server.run()
    DispatchQueue.main.async {
        WorkspaceDesktop.shared.shutdown()
        NSApp.terminate(nil)
    }
}

application.run()
