@testable import CodeckCore
import XCTest

final class MarkdownMediaTests: XCTestCase {
    func testRecognizesMovieExtensionFromPathOnly() throws {
        for destination in ["Movies/demo.mp4", "demo.M4V?download=1#frame", "https://example.com/demo.mov", "clip.webm#t=2", "clip%2Emp4"] {
            let markdown = "![Demo](\(destination))"
            let match = try XCTUnwrap(MarkdownMedia.parse(in: markdown, at: markdown.startIndex))
            XCTAssertTrue(match.media.isVideo, destination)
        }
        for destination in ["image.gif", "image.png?video=demo.mp4", "movie.mp4/preview.png", "https://example.com/mp4", "https://example.mp4",
                            "demo.mp4.png"]
        {
            let markdown = "![Demo](\(destination))"
            let match = try XCTUnwrap(MarkdownMedia.parse(in: markdown, at: markdown.startIndex))
            XCTAssertFalse(match.media.isVideo, destination)
        }
    }

    func testParsesBalancedAndEscapedDestinationsAndTitles() throws {
        let markdown = #"Before ![A \[detail\] & "quote"](Images/figure_(2).png "A \"title\"") after"#
        let imageStart = try XCTUnwrap(markdown.firstIndex(of: "!"))
        let image = try XCTUnwrap(MarkdownMedia.parse(in: markdown, at: imageStart))
        XCTAssertEqual(image.media.altText, #"A [detail] & "quote""#)
        XCTAssertEqual(image.media.destination, "Images/figure_(2).png")
        XCTAssertEqual(image.media.title, #"A "title""#)
        XCTAssertEqual(String(markdown[image.range]), #"![A \[detail\] & "quote"](Images/figure_(2).png "A \"title\"")"#)
        let movieMarkdown = "![Movie](<Movies/my clip.mp4> 'Demo')"
        let movie = try XCTUnwrap(MarkdownMedia.parse(in: movieMarkdown, at: movieMarkdown.startIndex))
        XCTAssertEqual(movie.media.destination, "Movies/my clip.mp4")
        XCTAssertEqual(movie.media.title, "Demo")
        XCTAssertTrue(movie.media.isVideo)

        let escapedMarkdown = #"![Alt](Images/unbalanced\).png (Caption))"#
        let escaped = try XCTUnwrap(MarkdownMedia.parse(in: escapedMarkdown, at: escapedMarkdown.startIndex))
        XCTAssertEqual(escaped.media.destination, "Images/unbalanced).png")
        XCTAssertEqual(escaped.media.title, "Caption")
    }

    func testAcceptsOnlyStandaloneBackgroundImages() throws {
        let background = try XCTUnwrap(MarkdownMedia.background(in: #"  ![bg Evening sky](<Images/evening sky.gif> "Background") "#))
        XCTAssertEqual(background.destination, "Images/evening sky.gif")
        XCTAssertEqual(background.backgroundDescription, "Evening sky")
        XCTAssertEqual(background.title, "Background")
        XCTAssertNotNil(MarkdownMedia.background(in: "![bg](image.png)"))

        for markdown in [
            "Text ![bg](a.png)", "![bg](a.png) text", "![bg](a.png) ![bg](b.png)",
            "- ![bg](a.png)", "> ![bg](a.png)", "    ![bg](a.png)", "\t![bg](a.png)",
            "`![bg](a.png)`", #"\![bg](a.png)"#, "![background](a.png)", "![bg](movie.mp4)",
        ] {
            XCTAssertNil(MarkdownMedia.background(in: markdown), markdown)
        }
    }

    func testLeavesMalformedMediaUnmatched() {
        for markdown in ["![Alt](missing", "![Alt](unbalanced(.png)", "![Alt](<missing.png)", "![Alt](image.png no-title)"] {
            XCTAssertNil(MarkdownMedia.parse(in: markdown, at: markdown.startIndex), markdown)
        }
    }
}
