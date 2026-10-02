@testable import CodeckMCP
import Foundation
import XCTest

final class PickedFileGrantsTests: XCTestCase {
    func testOnlyPickedCanonicalFilePersistsAcrossRestart() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let allowed = root.appendingPathComponent("allowed")
        let outside = root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: allowed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let file = outside.appendingPathComponent("chosen.mdeck")
        try "# Deck".write(to: file, atomically: true, encoding: .utf8)
        let guarder = PathAccessGuard(allowedRoots: [allowed])
        XCTAssertThrowsError(try guarder.resolve(file.path))
        let canonical = try guarder.grantPickedFile(file)
        XCTAssertEqual(try PathAccessGuard(allowedRoots: [allowed]).resolve(file.path), canonical)
        XCTAssertThrowsError(try guarder.resolve(outside.appendingPathComponent("other.mdeck").path))
        XCTAssertThrowsError(try guarder.grantPickedFile(outside.appendingPathComponent("private.txt")))
        let link = root.appendingPathComponent("chosen.mdeck")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertEqual(try guarder.resolve(link.path), canonical)
    }

    func testSymlinkedGrantStoreCannotAuthorizeOutsideFiles() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let allowed = root.appendingPathComponent("allowed")
        let outside = root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: allowed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let file = outside.appendingPathComponent("chosen.mdeck")
        try JSONEncoder().encode([file.path]).write(to: outside.appendingPathComponent("picked-files.json"))
        try FileManager.default.createSymbolicLink(at: allowed.appendingPathComponent(".codeck-workspaces"), withDestinationURL: outside)
        let guarder = PathAccessGuard(allowedRoots: [allowed])
        XCTAssertThrowsError(try guarder.resolve(file.path))
        XCTAssertThrowsError(try guarder.grantPickedFile(file))
    }
}
