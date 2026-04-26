import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
  let html: String
  let baseURL: URL?
  var onAction: ((MarkdownWebAction) -> Void)? = nil

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.add(context.coordinator, name: "codeck")

    let webView = WKWebView(frame: .zero, configuration: configuration)
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
    webView.loadHTMLString(html, baseURL: baseURL)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onAction: onAction)
  }

  static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
    webView.configuration.userContentController.removeScriptMessageHandler(forName: "codeck")
  }

  final class Coordinator: NSObject, WKScriptMessageHandler {
    var lastHTML: String?
    var lastBaseURL: URL?
    var onAction: ((MarkdownWebAction) -> Void)?

    init(onAction: ((MarkdownWebAction) -> Void)?) {
      self.onAction = onAction
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      guard message.name == "codeck",
            let body = message.body as? NSDictionary,
            let action = body["action"] as? String else {
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
