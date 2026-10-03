import AppKit
@testable import Codeck
import SwiftUI
import XCTest

@MainActor
final class MarkdownTextEditorViewTests: XCTestCase {
    func testRecreatingEditorDoesNotReplayFormattingCommand() {
        var source = "Hello world"
        let controller = MarkdownEditorController()
        let editor = MarkdownTextEditorView(
            text: Binding(get: { source }, set: { source = $0 }),
            controller: controller
        )
        let coordinator = editor.makeCoordinator()
        let textView = NSTextView()
        textView.string = source
        textView.setSelectedRange(NSRange(location: 6, length: 5))

        controller.toggle(.bold)
        coordinator.performPendingCommand(in: textView)
        XCTAssertEqual(source, "Hello **world**")

        let recreatedCoordinator = editor.makeCoordinator()
        recreatedCoordinator.performPendingCommand(in: textView)
        XCTAssertEqual(source, "Hello **world**")
        XCTAssertEqual(textView.string, source)

        controller.toggle(.bold)
        recreatedCoordinator.performPendingCommand(in: textView)
        XCTAssertEqual(source, "Hello world")
    }

    func testRepeatedViewUpdatesApplyInsertionOnlyOnce() {
        var source = ""
        let controller = MarkdownEditorController()
        let editor = MarkdownTextEditorView(
            text: Binding(get: { source }, set: { source = $0 }),
            controller: controller
        )
        let coordinator = editor.makeCoordinator()
        let textView = NSTextView()

        controller.insert(.heading1, codexBlockNumber: 1)
        coordinator.performPendingCommand(in: textView)
        let insertedSource = source
        XCTAssertFalse(insertedSource.isEmpty)

        coordinator.performPendingCommand(in: textView)
        XCTAssertEqual(source, insertedSource)
        XCTAssertEqual(textView.string, insertedSource)
    }
}
