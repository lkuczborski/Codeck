@testable import CodeckCore
import XCTest

final class MarkdownMediaRenderingTests: XCTestCase {
    func testRendersMoviesWithControlsAndImagesWithoutChangingTheirSource() {
        let html = render("""
        ![Movie](Movies/demo.MP4?download=1#t=2)

        ![Animation](Images/demo.gif)

        ![Image](Images/demo.png?movie=demo.mp4)
        """)
        let videos = tags(named: "video", in: html)
        XCTAssertEqual(videos.count, 1)
        XCTAssertTrue(videos[0].contains("src=\"Movies/demo.MP4?download=1#t=2\""))
        XCTAssertTrue(videos[0].contains("controls"))
        XCTAssertTrue(videos[0].contains("preload=\"auto\""))
        XCTAssertFalse(videos[0].contains("autoplay"))
        XCTAssertTrue(videos[0].contains("Movie"))
        let images = tags(named: "img", in: html)
        XCTAssertEqual(images.count, 2)
        XCTAssertTrue(images.contains { $0.contains("src=\"Images/demo.gif\"") })
        XCTAssertTrue(images.contains { $0.contains("src=\"Images/demo.png?movie=demo.mp4\"") })
    }

    func testEscapesMediaAttributesWithoutApplyingInlineFormattingInsideThem() throws {
        let html = render(#"![<script> & "caption" **bold**](<Images/a" & b.png> "A & title")"#)
        let image = try XCTUnwrap(tags(named: "img", in: html).first)
        XCTAssertTrue(image.contains("src=\"Images/a&quot; &amp; b.png\""))
        XCTAssertTrue(image.contains("alt=\"&lt;script&gt; &amp; &quot;caption&quot; **bold**\""))
        XCTAssertTrue(image.contains("title=\"A &amp; title\""))
        XCTAssertFalse(image.contains("<strong>"))
        XCTAssertFalse(image.contains("<script>"))
    }

    func testKeepsMediaSyntaxInsideCodeSpansAndEscapedTextLiteral() {
        let html = render(#"`![Inline](inline.png)` ``literal ` ![Double](double.mp4)`` \![Escaped](escaped.gif) **Bold** [Link](https://example.com)"#)
        XCTAssertTrue(tags(named: "img", in: html).isEmpty)
        XCTAssertTrue(tags(named: "video", in: html).isEmpty)
        XCTAssertTrue(html.contains("<code>![Inline](inline.png)</code>"))
        XCTAssertTrue(html.contains("<code>literal ` ![Double](double.mp4)</code>"))
        XCTAssertTrue(html.contains("<strong>Bold</strong>"))
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">Link</a>"))
    }

    func testUnmatchedBacktickRunLeavesFollowingMediaVisible() {
        let html = render("`` ![Outside](outside.png) `tail`")
        XCTAssertEqual(tags(named: "img", in: html).count, 1)
        XCTAssertTrue(html.contains("<code>tail</code>"))
    }

    func testUsesFirstStandaloneBackgroundAndKeepsForegroundContent() throws {
        let html = render("""
        ![bg Sky & clouds](Images/first.gif)

        # Foreground

        ![bg](Images/ignored.png)

        ![Ordinary](Images/foreground.png)
        """)
        let images = tags(named: "img", in: html)
        XCTAssertEqual(images.count, 2)
        let background = try XCTUnwrap(images.first { $0.contains("class=\"slide-background\"") })
        XCTAssertTrue(background.contains("src=\"Images/first.gif\""))
        XCTAssertTrue(background.contains("alt=\"Sky &amp; clouds\""))
        XCTAssertFalse(html.contains("Images/ignored.png"))
        XCTAssertTrue(html.contains("<h1>Foreground</h1>"))
        XCTAssertTrue(images.contains { $0.contains("src=\"Images/foreground.png\"") && !$0.contains("slide-background") })
    }

    func testDoesNotExtractBackgroundsFromNestedOrInlineMarkdown() {
        for markdown in [
            "```markdown\n![bg](fence.png)\n```",
            "~~~markdown\n![bg](tilde.png)\n~~~",
            "`![bg](inline.png)`",
            "`multiline\n![bg](inline.png)\ncode`",
            "- ![bg](list.png)",
            "- Item\n\n    ![bg](continuation.png)",
            "> ![bg](quote.png)",
            "Paragraph\n![bg](paragraph.png)",
            "![bg](paragraph.png)\nCaption",
            "    ![bg](indented.png)",
            "![bg](movie.mp4)",
        ] {
            let html = render(markdown)
            XCTAssertFalse(tags(named: "img", in: html).contains { $0.contains("class=\"slide-background\"") }, markdown)
        }
    }

    func testDoesNotExtractBackgroundFromCodexOutput() {
        let slide = Slide(markdown: "```codex id=example\nDescribe a scene\n```")
        let html = MarkdownRenderer.htmlDocument(
            for: slide,
            theme: .studio,
            codexOutputs: ["example": CodexSessionOutput(state: .completed, text: "![bg](output.gif)")]
        )
        let images = tags(named: "img", in: html)
        XCTAssertEqual(images.count, 1)
        XCTAssertTrue(images[0].contains("src=\"output.gif\""))
        XCTAssertFalse(images[0].contains("slide-background"))
    }

    func testRecognizesBackgroundAfterACompletedList() {
        let html = render("- First item\n- Second item\n\n![bg](after-list.gif)\n\n# Title")
        let images = tags(named: "img", in: html)
        XCTAssertEqual(images.count, 1)
        XCTAssertTrue(images[0].contains("class=\"slide-background\""))
        XCTAssertTrue(images[0].contains("src=\"after-list.gif\""))
        XCTAssertTrue(html.contains("<li><p>First item</p></li>"))
        XCTAssertTrue(html.contains("<h1>Title</h1>"))
    }

    private func render(_ markdown: String) -> String {
        MarkdownRenderer.htmlDocument(for: Slide(markdown: markdown), theme: .studio, codexOutputs: [:])
    }

    private func tags(named name: String, in html: String) -> [String] {
        let pattern = "<\(name)\\b[^>]*>"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = html as NSString
        return expression.matches(in: html, range: NSRange(location: 0, length: source.length)).map {
            source.substring(with: $0.range)
        }
    }
}
