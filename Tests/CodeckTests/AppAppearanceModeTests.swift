import AppKit
@testable import Codeck
import SwiftUI
import UniformTypeIdentifiers
import XCTest

final class AppAppearanceModeTests: XCTestCase {
    @MainActor
    func testNativePickerActionUsesUpdatedBinding() {
        var originalMode = AppAppearanceMode.automatic
        var currentMode = AppAppearanceMode.automatic
        let coordinator = NativeAppearancePicker.Coordinator(selection: Binding(
            get: { originalMode },
            set: { originalMode = $0 }
        ))
        coordinator.selection = Binding(get: { currentMode }, set: { currentMode = $0 })
        let control = NSSegmentedControl()
        control.segmentCount = AppAppearanceMode.allCases.count
        control.selectedSegment = 1

        coordinator.selectAppearance(control)

        XCTAssertEqual(currentMode, .dark)
        XCTAssertEqual(originalMode, .automatic)
    }

    @MainActor
    func testNativePickerIgnoresMissingSelection() {
        var mode = AppAppearanceMode.automatic
        let coordinator = NativeAppearancePicker.Coordinator(selection: Binding(get: { mode }, set: { mode = $0 }))
        let control = NSSegmentedControl()
        control.segmentCount = AppAppearanceMode.allCases.count
        control.selectedSegment = -1

        coordinator.selectAppearance(control)

        XCTAssertEqual(mode, .automatic)
    }

    func testAppearanceModeLabelsAndIconsMatchToolbarOptions() {
        XCTAssertEqual(AppAppearanceMode.allCases.map(\.rawValue), ["light", "dark", "automatic"])
        XCTAssertEqual(AppAppearanceMode.allCases.map(\.title), ["Light", "Dark", "Automatic"])
        XCTAssertEqual(AppAppearanceMode.allCases.map(\.systemImage), ["sun.max.fill", "moon.fill", "circle.lefthalf.filled"])
        XCTAssertEqual(AppAppearanceMode.storageKey, "appAppearanceMode")
    }

    func testCodeckDeckTypeIsPlainTextMDeckDocument() {
        XCTAssertEqual(UTType.codeckDeck.identifier, "com.luku.Codeck.mdeck")
        XCTAssertTrue(UTType.codeckDeck.conforms(to: .plainText))
        XCTAssertTrue(UTType.legacyMarkdown.conforms(to: .plainText))
    }
}
