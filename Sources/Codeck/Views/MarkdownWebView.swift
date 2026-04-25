import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
  let html: String
  let baseURL: URL?

  func makeNSView(context: Context) -> WKWebView {
    let webView = WKWebView()
    webView.setValue(false, forKey: "drawsBackground")
    webView.allowsMagnification = true
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {
    guard context.coordinator.lastHTML != html || context.coordinator.lastBaseURL != baseURL else {
      return
    }

    context.coordinator.lastHTML = html
    context.coordinator.lastBaseURL = baseURL
    webView.loadHTMLString(html, baseURL: baseURL)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator {
    var lastHTML: String?
    var lastBaseURL: URL?
  }
}
