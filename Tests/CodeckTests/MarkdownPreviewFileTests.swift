@testable import Codeck
import Foundation
import XCTest

final class MarkdownPreviewFileTests: XCTestCase {
    func testKeepsOrdinaryAndRemoteMediaOnTheExistingLoadingPath() throws {
        for html in [
            "<img src=\"image.gif\">",
            "<video src=\"https://example.com/movie.mp4\"></video>",
            "<video src=\"//example.com/movie.mp4\"></video>",
            "<video src=\"data:video/mp4;base64,AAAA\"></video>",
        ] {
            XCTAssertNil(try MarkdownPreviewFile.prepare(html: html, baseURL: URL(fileURLWithPath: "/tmp", isDirectory: true)))
        }
        XCTAssertNil(try MarkdownPreviewFile.prepare(html: "<video src=\"relative.mp4\"></video>", baseURL: nil))
        XCTAssertNil(try MarkdownPreviewFile.prepare(html: "<video src=\"/remote.mp4\"></video>", baseURL: URL(string: "https://example.com/")))
    }

    func testStagesLocalAssetsAndDeduplicatesCanonicalFiles() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deckDirectory = directory.appendingPathComponent("Deck & \"Title\"", isDirectory: true)
        try FileManager.default.createDirectory(at: deckDirectory, withIntermediateDirectories: true)
        let movie = deckDirectory.appendingPathComponent("movie.mp4")
        let image = directory.appendingPathComponent("poster.png")
        let animation = deckDirectory.appendingPathComponent("a\" & b.gif")
        let literalPercent = deckDirectory.appendingPathComponent("literal%20name.png")
        let bytes = Data("asset fixture".utf8)
        for file in [movie, image, animation, literalPercent] {
            try bytes.write(to: file)
        }
        try FileManager.default.createSymbolicLink(at: deckDirectory.appendingPathComponent("alias.mp4"), withDestinationURL: movie)
        let html = """
        <html><head></head><body>
        <video src="movie.mp4?download=1#t=1%2C2&amp;x=1" controls></video>
        <video src="alias.mp4"></video>
        <video src="\(movie.absoluteString.replacingOccurrences(of: "&", with: "&amp;"))"></video>
        <img src="\(image.path)">
        <img class="slide-background" src="a&quot;%20&amp;%20b.gif">
        <img src="literal%2520name.png">
        <a href="details.md">Details</a>
        </body></html>
        """
        let preview = try XCTUnwrap(MarkdownPreviewFile.prepare(html: html, baseURL: deckDirectory))
        defer { preview.cleanup() }
        let stagedHTML = try String(contentsOf: preview.fileURL, encoding: .utf8)
        let sources = mediaSources(in: stagedHTML)
        XCTAssertEqual(sources.count, 6)
        let urls = try sources.map { try XCTUnwrap(URL(string: $0)) }
        for url in urls {
            XCTAssertTrue(url.isFileURL)
            XCTAssertEqual((url.path as NSString).deletingLastPathComponent, preview.directoryURL.path)
            XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: url.path)), bytes)
        }
        XCTAssertEqual(urls[0].path, urls[1].path)
        XCTAssertEqual(urls[0].path, urls[2].path)
        XCTAssertEqual(urls[0].fragment, "t=1,2&x=1")
        XCTAssertEqual(urls.map(\.pathExtension), ["mp4", "mp4", "mp4", "png", "gif", "png"])
        let contents = try FileManager.default.contentsOfDirectory(atPath: preview.directoryURL.path)
        XCTAssertEqual(contents.count, 5)
        XCTAssertTrue(stagedHTML.contains("<a href=\"details.md\">Details</a>"))
        let escapedBase = deckDirectory.absoluteString.replacingOccurrences(of: "&", with: "&amp;")
        XCTAssertTrue(stagedHTML.contains("<head><base href=\"\(escapedBase)\">"))
        let sourceAttributes = try FileManager.default.attributesOfItem(atPath: movie.path)
        let linkedAttributes = try FileManager.default.attributesOfItem(atPath: urls[0].path)
        XCTAssertEqual(sourceAttributes[.systemFileNumber] as? NSNumber, linkedAttributes[.systemFileNumber] as? NSNumber)
    }

    func testMissingAssetsAndExternalSourcesDoNotPreventStaging() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let html = """
        <html><head></head><body>
        <video src="missing.mp4"></video>
        <img src="missing.png">
        <img src="https://example.com/remote.png">
        <video src="https://example.com/remote.mp4"></video>
        <img src="data:image/gif;base64,AAAA">
        </body></html>
        """
        let preview = try XCTUnwrap(MarkdownPreviewFile.prepare(html: html, baseURL: directory))
        defer { preview.cleanup() }
        let stagedHTML = try String(contentsOf: preview.fileURL, encoding: .utf8)
        XCTAssertEqual(mediaSources(in: stagedHTML), mediaSources(in: html))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: preview.directoryURL.path), ["slide.html"])
    }

    func testAbsoluteVideoWithoutBaseAndIndependentGenerationCleanup() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let movie = directory.appendingPathComponent("movie.mov")
        try Data("movie".utf8).write(to: movie)
        let html = "<html><head></head><body><video src=\"\(movie.path)\"></video></body></html>"
        let first = try XCTUnwrap(MarkdownPreviewFile.prepare(html: html, baseURL: nil))
        var second = try MarkdownPreviewFile.prepare(html: html, baseURL: nil)
        let secondDirectory = try XCTUnwrap(second?.directoryURL)
        weak var releasedPreview = second
        XCTAssertNotEqual(first.directoryURL, secondDirectory)
        first.cleanup()
        first.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.directoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: movie.path))
        second = nil
        XCTAssertNil(releasedPreview)
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondDirectory.path))
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("codeck-preview-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func mediaSources(in html: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: #"<(?:img|video)\b[^>]*?\bsrc="([^"]+)""#) else { return [] }
        let text = html as NSString
        return expression.matches(in: html, range: NSRange(location: 0, length: text.length)).map {
            text.substring(with: $0.range(at: 1)).replacingOccurrences(of: "&amp;", with: "&")
        }
    }
}
