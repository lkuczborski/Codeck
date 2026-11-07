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
        defer { page.close() }

        for theme in PresentationTheme.allCases {
            let presentation = MarkdownRenderer.presentationHTMLDocument(for: slide, theme: theme, codexOutputs: [:])
            try await page.load(presentation, size: CGSize(width: 1920, height: 1200))
            let expected = try await page.layout()
            let imageHeight = try await page.number("document.querySelector('img').offsetHeight")
            XCTAssertGreaterThan(imageHeight, 0)
            XCTAssertLessThan(imageHeight, 900)
            try await page.assertContentFits()

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
        defer { page.close() }
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
        defer { page.close() }
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
        defer { page.close() }
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

    func testPortraitAndMultipleImagesFitWithHeadingsAndCaptions() async throws {
        let slide = Slide(markdown: """
        # Portraits and captions

        This heading and paragraph need room above the images.

        ![Portrait](\(svgURL(width: 1200, height: 2400)))

        Caption for the portrait.

        ![Landscape](\(svgURL(width: 2400, height: 1200)))

        Caption for the landscape.
        """)
        let page = PresentationPageLoader()
        defer { page.close() }
        for html in [
            MarkdownRenderer.presentationHTMLDocument(for: slide, theme: .studio, codexOutputs: [:]),
            MarkdownRenderer.scaledPreviewHTMLDocument(for: slide, theme: .studio, codexOutputs: [:]),
        ] {
            try await page.load(html, size: CGSize(width: 800, height: 450))
            try await page.assertContentFits()
            try await page.assertMediaAspectRatios()
            let count = try await page.number("document.querySelectorAll('.slide-content img').length")
            XCTAssertEqual(count, 2)
            let smallestHeight = try await page.number("Math.min(...Array.from(document.querySelectorAll('.slide-content img'), image => image.height))")
            XCTAssertGreaterThan(smallestHeight, 40)
        }
    }

    func testLinkedAndEmphasizedImagesRemainVisibleAndFit() async throws {
        let imageURL = svgURL(width: 1200, height: 2400)
        let slide = Slide(markdown: """
        # Wrapped images

        [![Linked portrait](\(imageURL))](https://example.com)

        **![Emphasized portrait](\(imageURL))**
        """)
        let page = PresentationPageLoader()
        defer { page.close() }
        try await page.load(
            MarkdownRenderer.presentationHTMLDocument(for: slide, theme: .studio, codexOutputs: [:]),
            size: CGSize(width: 800, height: 450)
        )
        let count = try await page.number("document.querySelectorAll('a img,strong img').length")
        XCTAssertEqual(count, 2)
        let smallestWidth = try await page.number("Math.min(...Array.from(document.querySelectorAll('.slide-content img'), image => image.width))")
        XCTAssertGreaterThan(smallestWidth, 40)
        try await page.assertContentFits()
        try await page.assertMediaAspectRatios()
    }

    func testSmallImagesAreNotEnlarged() async throws {
        let slide = Slide(markdown: "# Small image\n\n![Icon](\(svgURL(width: 80, height: 40)))")
        let page = PresentationPageLoader()
        defer { page.close() }
        try await page.load(
            MarkdownRenderer.presentationHTMLDocument(for: slide, theme: .studio, codexOutputs: [:]),
            size: CGSize(width: 1600, height: 900)
        )
        let width = try await page.number("document.querySelector('img').width")
        let height = try await page.number("document.querySelector('img').height")
        XCTAssertEqual(width, 80)
        XCTAssertEqual(height, 40)
    }

    func testImagesFitInsideTwoColumnTable() async throws {
        let imageURL = svgURL(width: 2400, height: 600)
        let slide = Slide(markdown: """
        # Image comparison

        | Before | After |
        | --- | --- |
        | ![Before](\(imageURL)) | ![After](\(imageURL)) |
        """)
        let page = PresentationPageLoader()
        defer { page.close() }
        try await page.load(
            MarkdownRenderer.presentationHTMLDocument(for: slide, theme: .studio, codexOutputs: [:]),
            size: CGSize(width: 800, height: 450)
        )
        try await page.assertContentFits()
        try await page.assertMediaAspectRatios()
        let overflow = try await page.number("document.querySelector('table').offsetWidth - document.querySelector('.slide-content').clientWidth")
        XCTAssertLessThanOrEqual(overflow, 1)
        let smallestWidth = try await page.number("Math.min(...Array.from(document.querySelectorAll('td img'), image => image.width))")
        XCTAssertGreaterThan(smallestWidth, 100)
    }

    func testMediaRefitsAfterImageLoadAndResponsiveViewportResize() async throws {
        let slide = Slide(markdown: "# Loaded later\n\n![Portrait](\(svgURL(width: 40, height: 80)))\n\nA caption below the image.")
        let page = PresentationPageLoader()
        defer { page.close() }
        try await page.load(
            MarkdownRenderer.htmlDocument(for: slide, theme: .studio, codexOutputs: [:]),
            size: CGSize(width: 800, height: 650)
        )
        let imageURL = svgURL(width: 1200, height: 2400)
        _ = try await page.webView.evaluateJavaScript("document.querySelector('img').src = '\(imageURL)'")
        try await page.waitUntil("document.querySelector('img').naturalHeight === 2400")
        try await page.settleLayout()
        try await page.assertContentFits()
        try await page.assertMediaAspectRatios()
        let initialHeight = try await page.number("document.querySelector('img').height")

        page.webView.setFrameSize(CGSize(width: 500, height: 400))
        _ = try await page.webView.evaluateJavaScript("window.dispatchEvent(new Event('resize'))")
        try await page.settleLayout()
        try await page.assertContentFits()
        try await page.assertMediaAspectRatios()
        let resizedHeight = try await page.number("document.querySelector('img').height")
        XCTAssertLessThan(resizedHeight, initialHeight)
        XCTAssertGreaterThan(resizedHeight, 0)
    }

    func testAnimatedGIFFitsTemplatePreviewAndPreservesItsSource() async throws {
        let gif = try Data(contentsOf: mediaFixture("portrait.gif"))
        let imageURL = "data:image/gif;base64," + gif.base64EncodedString()
        let slide = Slide(markdown: "# GIF preview\n\n![Animation](\(imageURL))\n\nAnimated caption.")
        let page = PresentationPageLoader()
        defer { page.close() }
        try await page.load(
            MarkdownRenderer.templatePreviewHTMLDocument(for: slide, theme: .studio),
            size: CGSize(width: 420, height: 236)
        )
        try await page.assertContentFits()
        try await page.assertMediaAspectRatios()
        let source = try await page.webView.evaluateJavaScript("document.querySelector('img').src") as? String
        XCTAssertEqual(source, imageURL)
        let height = try await page.number("document.querySelector('img').height")
        XCTAssertGreaterThan(height, 0)
        XCTAssertLessThan(height, 240)
    }

    func testMovieRefitsWhenMetadataArrivesAndRetainsPlaybackControls() async throws {
        let slide = Slide(markdown: "# Portrait movie\n\n![Movie description](portrait.mp4)\n\nThe full frame should remain visible.")
        let page = PresentationPageLoader()
        defer { page.close() }
        try await page.load(
            MarkdownRenderer.presentationHTMLDocument(for: slide, theme: .studio, codexOutputs: [:]),
            size: CGSize(width: 800, height: 450)
        )
        let placeholderHeight = try await page.number("document.querySelector('video').clientHeight")
        // Detached WebKit views do not start movie loading. Exercise the metadata event with known intrinsic dimensions.
        _ = try await page.webView.evaluateJavaScript("""
        const movie = document.querySelector('video');
        Object.defineProperty(movie, 'videoWidth', {value: 600});
        Object.defineProperty(movie, 'videoHeight', {value: 1200});
        movie.dispatchEvent(new Event('loadedmetadata'));
        """)
        try await page.settleLayout()
        try await page.assertContentFits()
        try await page.assertMediaAspectRatios()
        let controls = try await page.webView.evaluateJavaScript("document.querySelector('video').controls") as? Bool
        XCTAssertEqual(controls, true)
        let height = try await page.number("document.querySelector('video').clientHeight")
        XCTAssertGreaterThan(height, placeholderHeight)
        XCTAssertLessThan(height, 1200)
    }

    func testBackgroundGIFCoversSlideBehindForegroundInEveryPreview() async throws {
        let gif = try Data(contentsOf: mediaFixture("portrait.gif"))
        let imageURL = "data:image/gif;base64," + gif.base64EncodedString()
        let slide = Slide(markdown: "![bg Animated backdrop](\(imageURL))\n\n# Foreground title\n\nForeground paragraph.")
        let page = PresentationPageLoader()
        defer { page.close() }
        for html in [
            MarkdownRenderer.presentationHTMLDocument(for: slide, theme: .studio, codexOutputs: [:]),
            MarkdownRenderer.scaledPreviewHTMLDocument(for: slide, theme: .studio, codexOutputs: [:]),
            MarkdownRenderer.templatePreviewHTMLDocument(for: slide, theme: .studio),
        ] {
            try await page.load(html, size: CGSize(width: 420, height: 236.25))
            let result = try await page.webView.evaluateJavaScript("""
            (() => {
              const background = document.querySelector('img.slide-background');
              const slide = document.querySelector('.slide').getBoundingClientRect();
              const bounds = background.getBoundingClientRect();
              const heading = document.querySelector('h1').getBoundingClientRect();
              return {
                source: background.src,
                fit: getComputedStyle(background).objectFit,
                radius: getComputedStyle(background).borderRadius,
                edges: [bounds.left - slide.left, bounds.top - slide.top, bounds.right - slide.right, bounds.bottom - slide.bottom],
                foreground: Boolean(document.elementFromPoint(heading.left + 2, heading.top + 2)?.closest('h1'))
              };
            })()
            """) as? [String: Any]
            let background = try XCTUnwrap(result)
            XCTAssertEqual(background["source"] as? String, imageURL)
            XCTAssertEqual(background["fit"] as? String, "cover")
            XCTAssertEqual(background["radius"] as? String, "0px")
            XCTAssertEqual(background["foreground"] as? Bool, true)
            for edge in try XCTUnwrap(background["edges"] as? [Double]) {
                XCTAssertEqual(edge, 0, accuracy: 0.02)
            }
        }
    }

    private func svgURL(width: Int, height: Int) -> String {
        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='\(width)' height='\(height)'><rect width='100%' height='100%' fill='teal'/></svg>"
        return "data:image/svg+xml;base64," + Data(svg.utf8).base64EncodedString()
    }

    private func mediaFixture(_ filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Media")
            .appendingPathComponent(filename)
    }
}

@MainActor
private final class PresentationPageLoader: NSObject, WKNavigationDelegate {
    let webView = WKWebView()
    private var pending: CheckedContinuation<Void, Error>?
    private var navigationTimeout: Task<Void, Never>?

    override init() {
        super.init()
        webView.navigationDelegate = self
    }

    func close() {
        navigationTimeout?.cancel()
        webView.stopLoading()
    }

    func load(_ html: String, size: CGSize) async throws {
        webView.setFrameSize(size)
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            navigationTimeout = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                self?.finishLoading(.failure(NSError(
                    domain: "PresentationRenderingTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Timed out loading rendered slide"]
                )))
            }
            webView.loadHTMLString(html, baseURL: nil)
        }
        try await settleLayout()
    }

    func settleLayout() async throws {
        _ = try await webView.evaluateJavaScript("""
        window.codeckTestLayoutReady = false;
        setTimeout(() => { window.codeckTestLayoutReady = true; }, 0);
        """)
        try await waitUntil("window.codeckTestLayoutReady === true")
    }

    func waitUntil(_ condition: String) async throws {
        for _ in 0 ..< 250 {
            if try await webView.evaluateJavaScript(condition) as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw NSError(
            domain: "PresentationRenderingTests",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(condition)"]
        )
    }

    func assertContentFits(file: StaticString = #filePath, line: UInt = #line) async throws {
        let overflow = try await number("""
        (() => {
          const slide = document.querySelector('.slide');
          const content = document.querySelector('.slide-content');
          const style = getComputedStyle(slide);
          return content.offsetHeight - (slide.clientHeight - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom));
        })()
        """)
        XCTAssertLessThanOrEqual(overflow, 1, "Media and text overflow the slide content area", file: file, line: line)
        let horizontalOverflow = try await number("""
        (() => {
          const content = document.querySelector('.slide-content').getBoundingClientRect();
          return Math.max(0, ...Array.from(document.querySelectorAll('.slide-content img,.slide-content video'), media => {
            const bounds = media.getBoundingClientRect();
            return Math.max(content.left - bounds.left, bounds.right - content.right);
          }));
        })()
        """)
        XCTAssertLessThanOrEqual(horizontalOverflow, 1, "Media overflows the slide width", file: file, line: line)
    }

    func assertMediaAspectRatios(file: StaticString = #filePath, line: UInt = #line) async throws {
        let error = try await number("""
        Math.max(...Array.from(document.querySelectorAll('.slide-content img,.slide-content video'), media => {
          const width = media.naturalWidth || media.videoWidth;
          const height = media.naturalHeight || media.videoHeight;
          return Math.abs(media.clientWidth / media.clientHeight - width / height);
        }))
        """)
        XCTAssertLessThan(error, 0.02, "Media aspect ratio changed", file: file, line: line)
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
        finishLoading(.success(()))
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        finishLoading(.failure(error))
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        finishLoading(.failure(error))
    }

    private func finishLoading(_ result: Result<Void, Error>) {
        navigationTimeout?.cancel()
        pending?.resume(with: result)
        pending = nil
    }
}
