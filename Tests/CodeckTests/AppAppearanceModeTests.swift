import UniformTypeIdentifiers
import XCTest
@testable import Codeck

final class AppAppearanceModeTests: XCTestCase {
  func testAppearanceModeLabelsAndIconsMatchToolbarOptions() {
    XCTAssertEqual(AppAppearanceMode.allCases.map(\.rawValue), ["light", "dark", "automatic"])
    XCTAssertEqual(AppAppearanceMode.allCases.map(\.title), ["Light", "Dark", "Automatic"])
    XCTAssertEqual(AppAppearanceMode.allCases.map(\.systemImage), ["sun.max.fill", "moon.fill", "circle.lefthalf.filled"])
    XCTAssertEqual(AppAppearanceMode.storageKey, "appAppearanceMode")
  }

  func testCodeckDeckTypeIsPlainTextMDeckDocument() {
    XCTAssertEqual(UTType.codeckDeck.identifier, "dev.local.codeck.mdeck")
    XCTAssertTrue(UTType.codeckDeck.conforms(to: .plainText))
    XCTAssertTrue(UTType.legacyMarkdown.conforms(to: .plainText))
  }
}
