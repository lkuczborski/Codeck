import AppKit
import CodeckCore
import CodeckRuntime
import UniformTypeIdentifiers
import WebKit

@MainActor
final class WorkspaceDesktop: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    static let shared = WorkspaceDesktop()
    private var window: DeckWindow?
    private var webView: WKWebView?
    private var timer: Timer?
    private var selected = 0
    private var count = 0
    private var renderedVersion = -1
    private var previousOptions: NSApplication.PresentationOptions = []
    private var render: ((Int) throws -> String)?
    private var version: (() -> Int)?
    private var cardAction: ((Int, String, Bool) throws -> Void)?
    private let sessions = CodexSessionStore()
    private var runTimers: [String: Timer] = [:]

    func startConfiguredRun(_ run: CodeckCardRun, runs: CodeckCardRuns, directory: URL) {
        guard runTimers[run.id] == nil else { return }
        let block = CodexBlock(id: run.id, prompt: run.prompt, model: run.model,
                               reasoning: CodexReasoningEffort(rawValue: run.reasoning), profile: run.profile, sandbox: run.sandbox, title: run.title)
        sessions.run(block, workingDirectory: directory)
        runs.updateNative(run.id, output: sessions.output(for: run.id))
        runTimers[run.id] = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if runs.run(run.id)?.status == "stopped" { self.sessions.stop(run.id) }
                let output = self.sessions.output(for: run.id)
                runs.updateNative(run.id, output: output)
                if output.state != .running {
                    self.runTimers[run.id]?.invalidate()
                    self.runTimers[run.id] = nil
                }
            }
        }
    }

    func stopRun(_ id: String) {
        sessions.stop(id)
    }

    func shutdown() {
        sessions.stopAll()
        runTimers.values.forEach { $0.invalidate() }
        runTimers.removeAll()
        dismiss()
    }

    func chooseOpen() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open presentation"
        panel.allowedContentTypes = deckTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseSave(path: String?, title: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save presentation"
        panel.allowedContentTypes = deckTypes
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = URL(fileURLWithPath: path ?? "\(title).mdeck").lastPathComponent
        if let path { panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent() }
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    private var deckTypes: [UTType] {
        ["mdeck", "md", "markdown"].compactMap { UTType(filenameExtension: $0) }
    }

    func present(count: Int, initialIndex: Int, render: @escaping (Int) throws -> String,
                 version: @escaping () -> Int, cardAction: @escaping (Int, String, Bool) throws -> Void) throws
    {
        dismiss()
        self.count = count
        selected = min(max(initialIndex, 0), count - 1)
        self.render = render
        self.version = version
        self.cardAction = cardAction
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let window = DeckWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.isOpaque = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.title = "Codeck Presentation"
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "codeck")
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView
        self.window = window
        self.webView = webView
        window.keyHandler = { [weak self] event in
            guard let self else { return false }
            switch event.keyCode {
            case 53: dismiss()
            case 123, 126, 116: move(to: selected - 1)
            case 124, 125, 49, 121: move(to: selected + 1)
            case 115: move(to: 0)
            case 119: move(to: count - 1)
            default: return false
            }
            return true
        }
        try refresh()
        previousOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        NSApp.activate(ignoringOtherApps: true)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.version?() != self.renderedVersion else { return }
                try? self.refresh()
            }
        }
    }

    func dismiss() {
        guard window != nil else { return }
        timer?.invalidate()
        timer = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "codeck")
        window?.close()
        window = nil
        webView = nil
        render = nil
        cardAction = nil
        version = nil
        NSApp.presentationOptions = previousOptions
    }

    private func move(to index: Int) {
        selected = min(max(index, 0), count - 1)
        try? refresh()
    }

    private func refresh() throws {
        guard let render else { return }
        try webView?.loadHTMLString(Self.fullscreenHTML(render(selected)), baseURL: nil)
        renderedVersion = version?() ?? 0
    }

    nonisolated static func fullscreenHTML(_ renderedHTML: String) -> String {
        let fit = """
        <style>html,body{width:100%;height:100%;margin:0;overflow:hidden;background:var(--bg)}
        #deck-stage{width:1600px;height:900px;position:absolute;left:50%;top:50%;transform-origin:center;overflow:hidden}
        .slide{width:1600px;min-height:900px;padding:88px}h1{font-size:82px}h2{font-size:60px}h3{font-size:44px}
        img{max-height:558px}</style>
        """
        return renderedHTML.replacingOccurrences(of: "</head>", with: fit + "</head>")
            .replacingOccurrences(of: "<body>", with: "<body><div id=\"deck-stage\">")
            .replacingOccurrences(of: "</body>", with: """
            </div><script>
            function fit(){
              const scale=Math.min(innerWidth/1600,innerHeight/900);
              document.getElementById('deck-stage').style.transform='translate(-50%,-50%) scale('+scale+')';
            }
            window.addEventListener('resize',fit);fit();
            </script></body>
            """)
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
        if action == "runAllCodex" {
            // The renderer supplies only IDs from this slide; the callback validates
            // every ID against the immutable deck before launching a process.
            if let ids = body["ids"] as? [String] { for id in ids {
                try? cardAction?(selected, id, false)
            } }
            try? refresh()
            return
        }
        guard ["runCodex", "stopCodex"].contains(action), let id = body["id"] as? String else { return }
        try? cardAction?(selected, id, action == "stopCodex")
        try? refresh()
    }

    func webView(_: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        action.navigationType == .other && action.request.url?.scheme == "about" ? .allow : .cancel
    }
}

private final class DeckWindow: NSWindow {
    var keyHandler: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyHandler?(event) == true { return }
        super.sendEvent(event)
    }
}
