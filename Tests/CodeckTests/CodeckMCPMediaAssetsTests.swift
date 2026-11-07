@testable import CodeckCore
@testable import CodeckMCP
import Foundation
import XCTest

final class CodeckMCPMediaAssetsTests: XCTestCase {
    func testEmbedsRenderedBackgroundAndMoviesWithAuthorizedLocalSources() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let paths = PathAccessGuard(allowedRoots: [directory], grantStorage: NoMediaFileGrants())
        let bytes = Data("media fixture".utf8)
        for name in ["sky & clouds.gif", "demo.mp4", "demo.m4v", "demo.mov", "demo.webm"] {
            try bytes.write(to: directory.appendingPathComponent(name))
        }
        let markdown = """
        ![bg Sky](<sky & clouds.gif>)

        ![MP4](demo.mp4?download=1#t=2)

        ![M4V](demo.m4v)

        ![MOV](demo.mov)

        ![WEBM](demo.webm)
        """
        let rendered = MarkdownRenderer.htmlDocument(for: Slide(markdown: markdown), theme: .studio, codexOutputs: [:])
        let embedded = CodeckMCPMediaAssets.embeddingLocalSources(in: rendered, directory: directory, paths: paths)
        let payload = bytes.base64EncodedString()
        XCTAssertTrue(embedded.contains("class=\"slide-background\" src=\"data:image/gif;base64,\(payload)\""))
        XCTAssertTrue(embedded.contains("src=\"data:video/mp4;base64,\(payload)#t=2\""))
        XCTAssertTrue(embedded.contains("src=\"data:video/mp4;base64,\(payload)\""))
        XCTAssertTrue(embedded.contains("src=\"data:video/quicktime;base64,\(payload)\""))
        XCTAssertTrue(embedded.contains("src=\"data:video/webm;base64,\(payload)\""))
    }

    func testPreservesAuthorizationAndFileSizeLimits() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let allowed = directory.appendingPathComponent("allowed")
        try FileManager.default.createDirectory(at: allowed, withIntermediateDirectories: true)
        let paths = PathAccessGuard(allowedRoots: [allowed], grantStorage: NoMediaFileGrants())
        let outside = directory.appendingPathComponent("private.mp4")
        try Data("private media".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: allowed.appendingPathComponent("linked.mp4"), withDestinationURL: outside)
        try Data(repeating: 0, count: 5_000_001).write(to: allowed.appendingPathComponent("large.mp4"))
        try Data("unsupported".utf8).write(to: allowed.appendingPathComponent("file.txt"))
        let html = """
        <video src="../private.mp4" controls></video>
        <video src="linked.mp4" controls></video>
        <video src="large.mp4" controls></video>
        <video src="file.txt" controls></video>
        <video src="https://example.com/remote.mp4" controls></video>
        <video src="//example.com/remote.mp4" controls></video>
        <video src="file://\(outside.path)" controls></video>
        <img src="data:image/png;base64,AAAA">
        """
        XCTAssertEqual(CodeckMCPMediaAssets.embeddingLocalSources(in: html, directory: allowed, paths: paths), html)
        XCTAssertEqual(CodeckMCPMediaAssets.embeddingLocalSources(in: html, directory: nil, paths: paths), html)
    }

    func testEmbedsEncodedAndEscapedPathsWithoutMixingImageAndVideoTypes() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let paths = PathAccessGuard(allowedRoots: [directory], grantStorage: NoMediaFileGrants())
        let bytes = Data("media fixture".utf8)
        try bytes.write(to: directory.appendingPathComponent("a\" & b.mp4"))
        try bytes.write(to: directory.appendingPathComponent("literal%20name.mp4"))
        try bytes.write(to: directory.appendingPathComponent("still.png"))
        let html = """
        <video controls src="a&quot;%20&amp;%20b.mp4"></video>
        <video src="literal%2520name.mp4"></video>
        <img src="a&quot;%20&amp;%20b.mp4">
        <video src="still.png"></video>
        """
        let embedded = CodeckMCPMediaAssets.embeddingLocalSources(in: html, directory: directory, paths: paths)
        XCTAssertTrue(embedded.contains("<video controls src=\"data:video/mp4;base64,\(bytes.base64EncodedString())\"></video>"))
        XCTAssertTrue(embedded.contains("<video src=\"data:video/mp4;base64,\(bytes.base64EncodedString())\"></video>"))
        XCTAssertTrue(embedded.contains("<img src=\"a&quot;%20&amp;%20b.mp4\">"))
        XCTAssertTrue(embedded.contains("<video src=\"still.png\"></video>"))
    }

    private func temporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("codeck-media-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct NoMediaFileGrants: PickedFileGrantStorage {
    func contains(scope _: String, path _: String) throws -> Bool {
        false
    }

    func grant(scope _: String, path _: String) throws {
        throw CocoaError(.fileWriteNoPermission)
    }
}
