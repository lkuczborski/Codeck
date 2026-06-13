@testable import CodeckCore
import Foundation
import XCTest

final class CodeckDeckFileStoreTests: XCTestCase {
    func testCreatesAndLoadsDeckFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("Lesson.mdeck")
        let store = CodeckDeckFileStore()

        let created = try store.createDeck(
            at: url,
            settings: PresentationSettings(
                theme: .chalk,
                codex: DeckCodexSettings(model: "gpt-5.5", reasoning: .high, sandbox: "workspace-write")
            ),
            slideMarkdown: ["# One", "# Two"],
            createDirectories: true
        )
        let loaded = try store.loadDeck(at: url)

        XCTAssertEqual(created.slides.map(\.title), ["One", "Two"])
        XCTAssertEqual(loaded.theme, .chalk)
        XCTAssertEqual(loaded.settings.codex.reasoning, .high)
        XCTAssertEqual(loaded.settings.codex.sandbox, "workspace-write")
        XCTAssertEqual(loaded.slides.map(\.title), ["One", "Two"])
    }

    func testCreateDeckRequiresOverwriteForExistingFiles() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("Lesson.mdeck")
        let store = CodeckDeckFileStore()
        try store.createDeck(at: url, slideMarkdown: ["# Original"], createDirectories: true)

        XCTAssertThrowsError(try store.createDeck(at: url, slideMarkdown: ["# Replacement"])) { error in
            XCTAssertEqual(error as? CodeckDeckFileError, .fileAlreadyExists(url.path))
        }

        try store.createDeck(at: url, slideMarkdown: ["# Replacement"], overwrite: true)
        XCTAssertEqual(try store.loadDeck(at: url).slides.first?.title, "Replacement")
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeckDeckFileStoreTests")
            .appendingPathComponent(UUID().uuidString)
    }
}
