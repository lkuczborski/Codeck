@testable import CodeckMCP
import Foundation
import Security
import XCTest

final class PickedFileGrantsTests: XCTestCase {
    func testNativeKeychainGrantRoundTrip() throws {
        guard ProcessInfo.processInfo.environment["CODECK_TEST_KEYCHAIN"] == "1" else {
            throw XCTSkip("Set CODECK_TEST_KEYCHAIN=1 for the native Keychain integration check.")
        }
        let scope = "codeck-keychain-test-\(UUID().uuidString)"
        let path = "/tmp/\(UUID().uuidString).mdeck"
        let account = try JSONEncoder().encode([scope, path]).base64EncodedString()
        defer {
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.luku.Codeck.workspace.picked-files",
                kSecAttrAccount as String: account,
            ] as CFDictionary)
        }
        let storage = KeychainFileGrantStorage()
        XCTAssertFalse(try storage.contains(scope: scope, path: path))
        try storage.grant(scope: scope, path: path)
        try storage.grant(scope: scope, path: path)
        XCTAssertTrue(try KeychainFileGrantStorage().contains(scope: scope, path: path))
        XCTAssertFalse(try storage.contains(scope: scope + "-other", path: path))
    }

    func testOnlyPickedCanonicalFilePersistsAcrossRestart() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let allowed = root.appendingPathComponent("allowed")
        let outside = root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: allowed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let file = outside.appendingPathComponent("chosen.mdeck")
        try "# Deck".write(to: file, atomically: true, encoding: .utf8)
        let storage = MemoryFileGrantStorage()
        let guarder = PathAccessGuard(allowedRoots: [allowed], grantStorage: storage)
        XCTAssertThrowsError(try guarder.resolve(file.path))
        let canonical = try guarder.grantPickedFile(file)
        XCTAssertEqual(try PathAccessGuard(allowedRoots: [allowed], grantStorage: storage).resolve(file.path), canonical)
        XCTAssertThrowsError(try PathAccessGuard(allowedRoots: [outside], grantStorage: storage).resolve(root.appendingPathComponent("other.mdeck").path))
        XCTAssertThrowsError(try guarder.resolve(outside.appendingPathComponent("other.mdeck").path))
        XCTAssertThrowsError(try guarder.grantPickedFile(outside.appendingPathComponent("private.txt")))
        let link = root.appendingPathComponent("chosen.mdeck")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertEqual(try guarder.resolve(link.path), canonical)
    }

    func testWorkspaceJSONCannotForgeOrOverwritePickerGrants() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let allowed = root.appendingPathComponent("allowed")
        let workspace = allowed.appendingPathComponent(".codeck-workspaces")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let picked = root.appendingPathComponent("chosen.mdeck")
        let forged = root.appendingPathComponent("private.mdeck")
        let storage = MemoryFileGrantStorage()
        let guarder = PathAccessGuard(allowedRoots: [allowed], grantStorage: storage)
        _ = try guarder.grantPickedFile(picked)
        try JSONEncoder().encode([forged.path]).write(to: workspace.appendingPathComponent("picked-files.json"))
        let restarted = PathAccessGuard(allowedRoots: [allowed], grantStorage: storage)
        XCTAssertEqual(try restarted.resolve(picked.path).path, picked.path)
        XCTAssertThrowsError(try restarted.resolve(forged.path))
        XCTAssertThrowsError(try PathAccessGuard(allowedRoots: [root.appendingPathComponent("another-root")], grantStorage: storage).resolve(picked.path))
    }

    func testSymlinkedWorkspaceJSONCannotAuthorizeOutsideFiles() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let allowed = root.appendingPathComponent("allowed")
        let outside = root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: allowed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let file = outside.appendingPathComponent("chosen.mdeck")
        let forgedJSON = try JSONEncoder().encode([file.path])
        let jsonURL = outside.appendingPathComponent("picked-files.json")
        try forgedJSON.write(to: jsonURL)
        try FileManager.default.createSymbolicLink(at: allowed.appendingPathComponent(".codeck-workspaces"), withDestinationURL: outside)
        let guarder = PathAccessGuard(allowedRoots: [allowed], grantStorage: MemoryFileGrantStorage())
        XCTAssertThrowsError(try guarder.resolve(file.path))
        _ = try guarder.grantPickedFile(file)
        XCTAssertEqual(try guarder.resolve(file.path).path, file.path)
        XCTAssertEqual(try Data(contentsOf: jsonURL), forgedJSON)
    }

    func testUnavailableProtectedStorageFailsClosedWithoutBlockingAllowedRoots() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let guarder = PathAccessGuard(allowedRoots: [root], grantStorage: UnavailableFileGrantStorage())
        XCTAssertEqual(try guarder.resolve(root.appendingPathComponent("deck.mdeck").path).path, root.appendingPathComponent("deck.mdeck").path)
        XCTAssertEqual(try guarder.grantPickedFile(root.appendingPathComponent("deck.mdeck")).path, root.appendingPathComponent("deck.mdeck").path)
        XCTAssertThrowsError(try guarder.resolve(root.deletingLastPathComponent().appendingPathComponent("private.mdeck").path))
        XCTAssertThrowsError(try guarder.grantPickedFile(root.deletingLastPathComponent().appendingPathComponent("chosen.mdeck")))
    }
}

private final class MemoryFileGrantStorage: PickedFileGrantStorage {
    private var grants: [String: Set<String>] = [:]

    func contains(scope: String, path: String) throws -> Bool {
        grants[scope]?.contains(path) == true
    }

    func grant(scope: String, path: String) throws {
        grants[scope, default: []].insert(path)
    }
}

private struct UnavailableFileGrantStorage: PickedFileGrantStorage {
    func contains(scope _: String, path _: String) throws -> Bool {
        throw CocoaError(.fileReadNoPermission)
    }

    func grant(scope _: String, path _: String) throws {
        throw CocoaError(.fileWriteNoPermission)
    }
}
