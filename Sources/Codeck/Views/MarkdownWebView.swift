import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    var onAction: ((MarkdownWebAction) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "codeck")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onAction = onAction

        guard context.coordinator.lastHTML != html || context.coordinator.lastBaseURL != baseURL else {
            return
        }

        context.coordinator.lastHTML = html
        context.coordinator.lastBaseURL = baseURL
        context.coordinator.load(html, baseURL: baseURL, in: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onAction: onAction)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "codeck")
        coordinator.cleanupPreviews()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var lastHTML: String?
        var lastBaseURL: URL?
        var onAction: ((MarkdownWebAction) -> Void)?
        private var localPreview: MarkdownPreviewFile?
        private var retiredPreviews: [MarkdownPreviewFile] = []
        private var navigation: WKNavigation?

        init(onAction: ((MarkdownWebAction) -> Void)?) {
            self.onAction = onAction
        }

        func load(_ html: String, baseURL: URL?, in webView: WKWebView) {
            if let localPreview {
                retiredPreviews.append(localPreview)
            }
            localPreview = try? MarkdownPreviewFile.prepare(html: html, baseURL: baseURL)
            if let localPreview {
                navigation = webView.loadFileURL(localPreview.fileURL, allowingReadAccessTo: localPreview.directoryURL)
            } else {
                navigation = webView.loadHTMLString(html, baseURL: baseURL)
            }
        }

        func webView(_: WKWebView, didFinish navigation: WKNavigation!) {
            guard navigation === self.navigation else { return }
            retiredPreviews.forEach { $0.cleanup() }
            retiredPreviews.removeAll()
        }

        func cleanupPreviews() {
            localPreview?.cleanup()
            localPreview = nil
            retiredPreviews.forEach { $0.cleanup() }
            retiredPreviews.removeAll()
            navigation = nil
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "codeck",
                  let body = message.body as? NSDictionary,
                  let action = body["action"] as? String
            else {
                return
            }

            switch action {
            case "runCodex":
                if let id = body["id"] as? String {
                    onAction?(.runCodex(id))
                }
            case "stopCodex":
                if let id = body["id"] as? String {
                    onAction?(.stopCodex(id))
                }
            case "runAllCodex":
                onAction?(.runAllCodex)
            default:
                break
            }
        }
    }
}
