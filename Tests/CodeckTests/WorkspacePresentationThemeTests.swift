import AppKit
@testable import CodeckCore
@testable import CodeckMCP
import WebKit
import XCTest

@MainActor
final class WorkspacePresentationThemeTests: XCTestCase {
    func testFullscreenPreservesEveryThemeColor() async throws {
        let slide = Slide(markdown: """
        # Theme colors

        [Link](https://example.com)

        > Quoted text

        | Heading | Value |
        | --- | --- |
        | Cell | Text |

        ```swift
        let message = "Hello"
        ```

        ```codex id=colors
        Explain the theme.
        ```
        """)
        let loader = ThemePageLoader()
        let script = """
        Object.fromEntries(Array.from(document.querySelectorAll(
          'html,body,.slide,h1,a,blockquote,table,th,td,pre,.syntax-keyword,.syntax-string,.codex-card,.codex-card-heading,.codex-action'
        ), (element, index) => {
          const style = getComputedStyle(element);
          return [index, [style.color, style.backgroundColor, style.borderColor]];
        }))
        """
        for theme in PresentationTheme.allCases {
            let preview = MarkdownRenderer.htmlDocument(for: slide, theme: theme, codexOutputs: [:])
            try await loader.load(preview)
            let previewColors = try await loader.webView.evaluateJavaScript(script) as? [String: [String]]
            XCTAssertNotNil(previewColors)
            try await loader.load(WorkspaceDesktop.fullscreenHTML(preview))
            let fullscreenColors = try await loader.webView.evaluateJavaScript(script) as? [String: [String]]
            XCTAssertEqual(fullscreenColors, previewColors, "Fullscreen changed colors for \(theme)")
        }
    }
}

@MainActor
private final class ThemePageLoader: NSObject, WKNavigationDelegate {
    let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
    private var pending: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        webView.navigationDelegate = self
    }

    func load(_ html: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        pending?.resume()
        pending = nil
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        pending?.resume(throwing: error)
        pending = nil
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        pending?.resume(throwing: error)
        pending = nil
    }
}
