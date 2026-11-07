@testable import Codeck
import Foundation
import XCTest

final class MarkdownMediaInsertionTests: XCTestCase {
    func testVideoInsertionCreatesSeparateBlockAndSelectsPath() {
        let result = MarkdownEditorOperation.insert(
            .video,
            into: "# Demo",
            selection: NSRange(location: 6, length: 0),
            codexBlockNumber: 1
        )

        XCTAssertEqual(result.text, "# Demo\n\n![Video description](Movies/example.mp4)")
        XCTAssertEqual((result.text as NSString).substring(with: result.selection), "Movies/example.mp4")
    }

    func testBackgroundInsertionKeepsDirectiveOnItsOwnLineAndSelectsPath() {
        let text = "Intro\nreplace me\nOutro"
        let result = MarkdownEditorOperation.insert(
            .backgroundImage,
            into: text,
            selection: (text as NSString).range(of: "replace me"),
            codexBlockNumber: 1
        )

        XCTAssertEqual(result.text, "Intro\n\n![bg](Images/background.gif)\n\nOutro")
        XCTAssertEqual((result.text as NSString).substring(with: result.selection), "Images/background.gif")
    }
}
