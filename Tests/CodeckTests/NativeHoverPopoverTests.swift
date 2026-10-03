import AppKit
@testable import Codeck
import CodeckCore
import CodeckRuntime
import SwiftUI
import XCTest

@MainActor
final class NativeHoverPopoverTests: XCTestCase {
    func testPreviewSizeIsEstablishedBeforePopoverPlacement() throws {
        let deck = PresentationDeck(markdownDocument: "# Preview")
        let content = PresentationSlidePreviewPopover(
            deck: deck,
            selectedSlideID: deck.slides.first?.id,
            sessions: CodexSessionStore(),
            baseURL: nil,
            skimmedSlideIndex: .constant(nil),
            onHoverChanged: { _ in },
            onDetach: { _ in }
        )
        let coordinator = NativeHoverPopover.Coordinator(
            isPresented: .constant(false), contentSize: PresentationSlidePreviewPopover.contentSize, content: content
        )
        XCTAssertEqual(coordinator.popover.contentSize.width, 400, accuracy: 1)
        XCTAssertEqual(coordinator.popover.contentSize.height, 233.75, accuracy: 1)
        let controller = try XCTUnwrap(coordinator.popover.contentViewController)
        XCTAssertEqual(controller.view.bounds.width, 400, accuracy: 1)
        XCTAssertEqual(controller.view.bounds.height, 233.75, accuracy: 1)
    }
}
