import AppKit

enum AppAppearanceController {
  @MainActor
  static func apply(rawValue: String?) {
    let mode = rawValue.flatMap(AppAppearanceMode.init(rawValue:)) ?? .automatic
    apply(mode)
  }

  @MainActor
  static func apply(_ mode: AppAppearanceMode) {
    switch mode {
    case .automatic:
      NSApp.appearance = nil
    case .light:
      NSApp.appearance = NSAppearance(named: .aqua)
    case .dark:
      NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    refreshOpenWindows()
  }

  @MainActor
  private static func refreshOpenWindows() {
    for window in NSApp.windows {
      window.appearance = nil
      window.contentView?.codeckInvalidateAppearance()
      window.toolbar?.validateVisibleItems()
    }
  }
}

private extension NSView {
  func codeckInvalidateAppearance() {
    appearance = nil
    needsDisplay = true
    needsLayout = true
    subviews.forEach { $0.codeckInvalidateAppearance() }
    displayIfNeeded()
  }
}
