import AppKit
import CodeckCore
import SwiftUI

final class PresentationWindow: NSWindow {
  var keyHandler: ((NSEvent) -> Bool)?
  var onClose: (() -> Void)?
  private var isClosing = false

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, keyHandler?(event) == true {
      return
    }

    super.sendEvent(event)
  }

  override func close() {
    guard !isClosing else { return }
    isClosing = true

    let closeHandler = onClose
    keyHandler = nil
    onClose = nil

    super.close()
    closeHandler?()
  }
}
