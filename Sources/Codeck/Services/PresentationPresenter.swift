import AppKit
import SwiftUI

@MainActor
final class PresentationPresenter: ObservableObject {
  private var window: PresentationWindow?
  private var playbackState: PresentationPlaybackState?

  func present(
    deck: PresentationDeck,
    selectedSlideID: Slide.ID?,
    baseURL: URL?,
    sessions: CodexSessionStore
  ) {
    dismiss()

    let playbackState = PresentationPlaybackState(deck: deck, initialSlideID: selectedSlideID)
    let screen = NSApp.keyWindow?.screen ?? NSScreen.main
    let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)

    let window = PresentationWindow(
      contentRect: frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false,
      screen: screen
    )
    window.isReleasedWhenClosed = false
    window.backgroundColor = .black
    window.isOpaque = true
    window.level = .screenSaver
    window.collectionBehavior = [.canJoinAllSpaces, .stationary]
    window.contentViewController = NSHostingController(
      rootView: PresentationModeView(
        playbackState: playbackState,
        sessions: sessions,
        baseURL: baseURL
      )
    )

    window.keyHandler = { [weak self, weak playbackState] event in
      switch event.keyCode {
      case 53:
        self?.dismiss()
        return true
      case 123:
        playbackState?.movePrevious()
        return true
      case 124:
        playbackState?.moveNext()
        return true
      default:
        return false
      }
    }
    window.onClose = { [weak self] in
      self?.window = nil
      self?.playbackState = nil
    }

    self.playbackState = playbackState
    self.window = window

    NSApp.activate(ignoringOtherApps: true)
    window.setFrame(frame, display: true)
    window.makeKeyAndOrderFront(nil)
  }

  func dismiss() {
    guard let window else { return }
    self.window = nil
    playbackState = nil
    window.close()
  }
}

private final class PresentationWindow: NSWindow {
  var keyHandler: ((NSEvent) -> Bool)?
  var onClose: (() -> Void)?
  private var isClosing = false

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

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
