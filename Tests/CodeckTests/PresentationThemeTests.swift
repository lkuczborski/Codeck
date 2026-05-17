import XCTest
@testable import CodeckCore
@testable import Codeck

final class PresentationThemeTests: XCTestCase {
  func testThemeDisplayNamesFollowPickerOrder() {
    XCTAssertEqual(PresentationTheme.allCases.map(\.rawValue), ["studio", "midnight", "chalk", "solar", "atelier"])
    XCTAssertEqual(PresentationTheme.allCases.map(\.displayName), ["Studio", "Midnight", "Chalk", "Solar", "Atelier"])
  }

  func testEveryThemeDefinesRendererColorVariables() {
    for theme in PresentationTheme.allCases {
      let css = theme.css

      XCTAssertTrue(css.contains("--bg:"), "Missing --bg for \(theme)")
      XCTAssertTrue(css.contains("--fg:"), "Missing --fg for \(theme)")
      XCTAssertTrue(css.contains("--accent:"), "Missing --accent for \(theme)")
      XCTAssertTrue(css.contains("--panel:"), "Missing --panel for \(theme)")
      XCTAssertTrue(css.contains("--code-bg:"), "Missing --code-bg for \(theme)")
      XCTAssertTrue(css.contains("--code-fg:"), "Missing --code-fg for \(theme)")
    }
  }
}
