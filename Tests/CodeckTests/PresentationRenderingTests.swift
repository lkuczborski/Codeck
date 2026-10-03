import AppKit
@testable import Codeck
@testable import CodeckCore
@testable import CodeckMCP
import CodeckRuntime
import SwiftUI
import WebKit
import XCTest

@MainActor
final class PresentationRenderingTests: XCTestCase {
    func testEditorPreviewResizesInsideNativeWindowWithoutViewTransform() throws {
        let view = PreviewPaneView(
            slide: Slide(markdown: "# Preview"),
            theme: .atelier,
            sessions: CodexSessionStore(),
            baseURL: nil,
            onRunBlock: { _ in },
            onRunAll: { _ in }
        )
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 440, height: 760),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        let webView = try XCTUnwrap(findWebView(in: host))
        let sizes = [CGSize(width: 440, height: 760), CGSize(width: 460, height: 700), CGSize(width: 800, height: 600),
                     CGSize(width: 1100, height: 260), CGSize(width: 440, height: 760)]
        for size in sizes {
            window.setContentSize(size)
            host.layoutSubtreeIfNeeded()
            let canvas = webView.convert(webView.bounds, to: host)
            let expectedWidth = min(size.width - 40, (size.height - 40) * 16 / 9)
            XCTAssertEqual(webView.bounds.width, expectedWidth, accuracy: 1)
            XCTAssertEqual(webView.bounds.height, expectedWidth * 9 / 16, accuracy: 1)
            XCTAssertEqual(canvas.width, expectedWidth, accuracy: 1)
            XCTAssertEqual(canvas.height, expectedWidth * 9 / 16, accuracy: 1)
            XCTAssertEqual(canvas.midX, size.width / 2, accuracy: 1)
            XCTAssertEqual(canvas.midY, size.height / 2, accuracy: 1)
        }
    }

    private func findWebView(in view: NSView) -> WKWebView? {
        if let webView = view as? WKWebView { return webView }
        for child in view.subviews {
            if let webView = findWebView(in: child) { return webView }
        }
        return nil
    }

    func testPreviewAndPresentationKeepTheSameLayoutAcrossViewportSizes() async throws {
        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='2000' height='1400'><rect width='2000' height='1400' fill='teal'/></svg>"
        let imageURL = "data:image/svg+xml;base64," + Data(svg.utf8).base64EncodedString()
        let slide = Slide(markdown: """
        # A long slide heading that should keep the same line breaks in every preview

        A paragraph whose text must wrap at the presentation canvas width, regardless of the editor pane or popover size.

        ![Illustration](\(imageURL))
        """)
        let page = PresentationPageLoader()

        for theme in PresentationTheme.allCases {
            let presentation = MarkdownRenderer.presentationHTMLDocument(for: slide, theme: theme, codexOutputs: [:])
            try await page.load(presentation, size: CGSize(width: 1920, height: 1200))
            let expected = try await page.layout()
            let imageHeight = try await page.number("document.querySelector('img').offsetHeight")
            XCTAssertEqual(imageHeight, 558)

            try await page.load(presentation, size: CGSize(width: 440, height: 760))
            let editorLayout = try await page.layout()
            XCTAssertEqual(editorLayout, expected, "Editor preview reflowed for \(theme)")

            let quickPreview = MarkdownRenderer.scaledPreviewHTMLDocument(for: slide, theme: theme, codexOutputs: [:])
            try await page.load(quickPreview, size: CGSize(width: 380, height: 213.75))
            let hoverLayout = try await page.layout()
            XCTAssertEqual(hoverLayout, expected, "Hover preview reflowed for \(theme)")

            let desktop = WorkspaceDesktop.fullscreenHTML(MarkdownRenderer.htmlDocument(for: slide, theme: theme, codexOutputs: [:]))
            try await page.load(desktop, size: CGSize(width: 1280, height: 720))
            let desktopLayout = try await page.layout()
            XCTAssertEqual(desktopLayout, expected, "MCP presentation changed the canvas for \(theme)")
        }
    }

    func testCanvasFitsBothDimensionsAndRespondsToResize() async throws {
        let page = PresentationPageLoader()
        let html = MarkdownRenderer.presentationHTMLDocument(for: Slide(markdown: "# Canvas"), theme: .studio, codexOutputs: [:])
        try await page.load(html, size: CGSize(width: 1100, height: 260))
        let shortHeight = try await page.number("document.querySelector('.slide').getBoundingClientRect().height")
        let shortWidth = try await page.number("document.querySelector('.slide').getBoundingClientRect().width")
        XCTAssertEqual(shortHeight, 260, accuracy: 0.01)
        XCTAssertEqual(shortWidth, 260 * 16 / 9, accuracy: 0.01)

        page.webView.setFrameSize(CGSize(width: 380, height: 214))
        _ = try await page.webView.evaluateJavaScript("window.dispatchEvent(new Event('resize'))")
        let resizedWidth = try await page.number("document.querySelector('.slide').getBoundingClientRect().width")
        let resizedHeight = try await page.number("document.querySelector('.slide').getBoundingClientRect().height")
        XCTAssertEqual(resizedWidth, 380, accuracy: 0.01)
        XCTAssertEqual(resizedHeight, 213.75, accuracy: 0.01)
    }

    func testModernCanvasResizesWithoutJavaScriptScaleUpdates() async throws {
        let page = PresentationPageLoader()
        let html = MarkdownRenderer.presentationHTMLDocument(for: Slide(markdown: "# Canvas"), theme: .studio, codexOutputs: [:])
        try await page.load(html, size: CGSize(width: 1600, height: 900))
        let supportsCSSScaling = try await page.webView.evaluateJavaScript("CSS.supports('transform', 'scale(calc(1px / 1px))')") as? Bool
        guard supportsCSSScaling == true else { throw XCTSkip("WebKit predates CSS typed arithmetic") }

        _ = try await page.webView.evaluateJavaScript("document.documentElement.style.setProperty('--codeck-slide-scale', '0.01')")
        for size in [CGSize(width: 440, height: 760), CGSize(width: 1100, height: 260), CGSize(width: 800, height: 450)] {
            page.webView.setFrameSize(size)
            let width = try await page.number("document.querySelector('.slide').getBoundingClientRect().width")
            let height = try await page.number("document.querySelector('.slide').getBoundingClientRect().height")
            let expectedWidth = min(size.width, size.height * 16 / 9)
            XCTAssertEqual(width, expectedWidth, accuracy: 0.01)
            XCTAssertEqual(height, expectedWidth * 9 / 16, accuracy: 0.01)
        }
    }

    func testPassivePreviewPreservesCodexCardGeometryAndHidesOnlyActions() async throws {
        let slide = Slide(markdown: """
        # Live card

        ```codex id=preview
        Explain the layout.
        ```

        ```swift
        let message = "Hello"
        ```
        """)
        let page = PresentationPageLoader()
        try await page.load(
            MarkdownRenderer.presentationHTMLDocument(for: slide, theme: .atelier, codexOutputs: [:]),
            size: CGSize(width: 1600, height: 900)
        )
        let expected = try await page.layout()
        try await page.load(
            MarkdownRenderer.scaledPreviewHTMLDocument(for: slide, theme: .atelier, codexOutputs: [:]),
            size: CGSize(width: 380, height: 213.75)
        )
        let hoverLayout = try await page.layout()
        XCTAssertEqual(hoverLayout, expected)
        let visibility = try await page.webView.evaluateJavaScript("getComputedStyle(document.querySelector('.codex-action')).visibility") as? String
        XCTAssertEqual(visibility, "hidden")
    }
}

@MainActor
private final class PresentationPageLoader: NSObject, WKNavigationDelegate {
    let webView = WKWebView()
    private var pending: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        webView.navigationDelegate = self
    }

    func load(_ html: String, size: CGSize) async throws {
        webView.setFrameSize(size)
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func layout() async throws -> String {
        let script = """
        JSON.stringify(Array.from(document.querySelectorAll('.slide,h1,p,img,pre,.codex-card,.codex-card-heading,.codex-action'), element => {
          const style = getComputedStyle(element);
          const isCanvas = element.classList.contains('slide');
          return [element.className, element.offsetWidth, element.offsetHeight, isCanvas ? 0 : element.offsetLeft, isCanvas ? 0 : element.offsetTop,
            style.fontSize, style.lineHeight, style.padding, style.gap, style.maxHeight];
        }))
        """
        let result = try await webView.evaluateJavaScript(script) as? String
        return try XCTUnwrap(result)
    }

    func number(_ expression: String) async throws -> Double {
        let result = try await webView.evaluateJavaScript(expression) as? Double
        return try XCTUnwrap(result)
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
