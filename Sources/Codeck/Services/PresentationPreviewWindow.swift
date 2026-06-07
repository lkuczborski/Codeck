import AppKit
import CodeckCore
import SwiftUI

final class PresentationPreviewWindow: NSWindow {
  var onClose: (() -> Void)?
  private var isClosing = false

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }

  override func close() {
    guard !isClosing else { return }
    isClosing = true

    let closeHandler = onClose
    onClose = nil

    super.close()
    closeHandler?()
  }
}
