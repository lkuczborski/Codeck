import CodeckCore
import Foundation
import XCTest

final class CodeckWorkspaceStoreTests: XCTestCase {
    private var directory: URL!
    private var store: CodeckWorkspaceStore!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("codeck-workspace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let root = directory!
        store = CodeckWorkspaceStore(directory: root.appendingPathComponent("state")) { path in
            let url = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
            guard url.path.hasPrefix(root.path + "/") else { throw CodeckWorkspaceError.invalid("Outside test root.") }
            return url
        }
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testDraftSurvivesAnotherStoreAndSavesExactMarkdown() throws {
        let source = "---\nformat: codeck.mdeck\ncustom: keep me\n---\n\n# Intro\n\n```swift\nlet x = 2\n```\n"
        let draft = try store.open(markdown: source, title: "Lesson")
        let state = try store.read(draft.id)
        XCTAssertEqual(state.markdown, source)
        XCTAssertTrue(state.dirty)
        let saved = try store.save(state.id, revision: state.revision, path: directory.appendingPathComponent("lesson.mdeck").path)
        XCTAssertFalse(saved.dirty)
        XCTAssertEqual(try String(contentsOfFile: XCTUnwrap(saved.path), encoding: .utf8), source)
        XCTAssertEqual(try store.open(path: saved.path).id, saved.id)
    }

    func testRejectsStaleDraftAndDoesNotOverwriteDiskChanges() throws {
        let path = directory.appendingPathComponent("lesson.mdeck")
        try "# Original".write(to: path, atomically: true, encoding: .utf8)
        let state = try store.open(path: path.path)
        let edited = try store.update(state.id, revision: state.revision, markdown: "# Edited locally")
        XCTAssertThrowsError(try store.update(state.id, revision: state.revision, markdown: "# Stale agent edit"))
        try "# Changed externally".write(to: path, atomically: true, encoding: .utf8)
        let conflict = try store.read(state.id)
        XCTAssertTrue(conflict.diskConflict)
        XCTAssertEqual(conflict.markdown, edited.markdown)
        XCTAssertThrowsError(try store.save(state.id, revision: conflict.revision, overwrite: true))
        XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), "# Changed externally")
        let copy = try store.save(state.id, revision: conflict.revision, path: directory.appendingPathComponent("copy.mdeck").path)
        XCTAssertFalse(copy.diskConflict)
        XCTAssertEqual(copy.markdown, "# Edited locally")
    }

    func testCleanDraftRefreshesExternalEditsAndExplicitReloadDiscardsDirtyDraft() throws {
        let path = directory.appendingPathComponent("lesson.mdeck")
        try "# First".write(to: path, atomically: true, encoding: .utf8)
        let state = try store.open(path: path.path)
        try "# Second".write(to: path, atomically: true, encoding: .utf8)
        let refreshed = try store.read(state.id)
        XCTAssertEqual(refreshed.markdown, "# Second")
        XCTAssertFalse(refreshed.dirty)
        let draft = try store.update(state.id, revision: refreshed.revision, markdown: "# Draft")
        let reload = try store.reload(state.id, revision: draft.revision)
        XCTAssertEqual(reload.markdown, "# Second")
        XCTAssertFalse(reload.dirty)
    }

    func testLegacyDraftWithAnnotationsStillLoadsWithoutLosingMarkdown() throws {
        let state = try store.open(markdown: "# Existing deck")
        let file = directory.appendingPathComponent("state/\(state.id).json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        json["annotations"] = [["id": "old-note", "text": "Legacy note", "resolved": false]]
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        XCTAssertEqual(try store.read(state.id).markdown, "# Existing deck")
        let updated = try store.update(state.id, revision: state.revision, markdown: "# Updated deck")
        let stored = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertNil(stored["annotations"])
        XCTAssertEqual(try store.read(updated.id).markdown, "# Updated deck")
    }

    func testLostFileApprovalPreservesDraftWithoutReadingDiskAndCanBeRenewed() throws {
        let file = directory.appendingPathComponent("selected.mdeck")
        try "# Original".write(to: file, atomically: true, encoding: .utf8)
        let initial = try store.open(path: file.path)
        var approved = false
        let root = try XCTUnwrap(directory)
        let restored = CodeckWorkspaceStore(directory: root.appendingPathComponent("state")) { path in
            if path == file.path, !approved { throw CocoaError(.fileReadNoPermission) }
            guard path.hasPrefix(root.path + "/") else { throw CocoaError(.fileReadNoPermission) }
            return URL(fileURLWithPath: path)
        }
        try "# Changed on disk".write(to: file, atomically: true, encoding: .utf8)
        for _ in 0 ..< 3 {
            XCTAssertEqual(try restored.read(initial.id), initial)
        }
        XCTAssertThrowsError(try restored.open(path: file.path))
        XCTAssertThrowsError(try restored.save(initial.id, revision: initial.revision))
        XCTAssertThrowsError(try restored.reload(initial.id, revision: initial.revision))
        let edited = try restored.update(initial.id, revision: initial.revision, markdown: "# Preserved draft")
        XCTAssertEqual(edited.markdown, "# Preserved draft")
        approved = true
        let reopened = try restored.open(path: file.path)
        XCTAssertEqual(reopened.id, initial.id)
        XCTAssertEqual(reopened.markdown, edited.markdown)
        XCTAssertTrue(reopened.diskConflict)
        XCTAssertThrowsError(try restored.save(initial.id, revision: reopened.revision))
        let reloaded = try restored.reload(initial.id, revision: reopened.revision)
        XCTAssertEqual(reloaded.markdown, "# Changed on disk")
    }

    func testLostFileApprovalStillAllowsSavingDraftToAuthorizedCopy() throws {
        let file = directory.appendingPathComponent("selected.mdeck")
        try "# Original".write(to: file, atomically: true, encoding: .utf8)
        let initial = try store.open(path: file.path)
        let root = try XCTUnwrap(directory)
        let restored = CodeckWorkspaceStore(directory: root.appendingPathComponent("state")) { path in
            guard path != file.path, path.hasPrefix(root.path + "/") else { throw CocoaError(.fileReadNoPermission) }
            return URL(fileURLWithPath: path)
        }
        let edited = try restored.update(initial.id, revision: initial.revision, markdown: "# Saved copy")
        let copy = directory.appendingPathComponent("copy.mdeck")
        let saved = try restored.save(initial.id, revision: edited.revision, path: copy.path)
        XCTAssertEqual(saved.path, copy.path)
        XCTAssertFalse(saved.dirty)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "# Original")
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), edited.markdown)
    }

    func testRejectsUnsafeStateIDsSaveExtensionsAndExistingDestinations() throws {
        XCTAssertThrowsError(try store.read("../../deck"))
        let draft = try store.open(markdown: "# Deck")
        XCTAssertThrowsError(try store.save(draft.id, revision: draft.revision, path: directory.appendingPathComponent("file.swift").path))
        let path = directory.appendingPathComponent("existing.mdeck")
        try "# Existing".write(to: path, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try store.save(draft.id, revision: draft.revision, path: path.path))
        XCTAssertNoThrow(try store.save(draft.id, revision: draft.revision, path: path.path, overwrite: true))
    }
}
