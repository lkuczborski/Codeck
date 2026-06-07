import AppKit
import CodeckCore
import SwiftUI

@MainActor
final class PresentationPreviewPresenter: ObservableObject {
  @Published private(set) var isPresented = false

  private let state = PresentationPreviewWindowState()
  private var window: PresentationPreviewWindow?
  private weak var sessions: CodexSessionStore?

  func present(
    deck: PresentationDeck,
    selectedSlideID: Slide.ID?,
    fallbackSlideIndex: Int?,
    baseURL: URL?,
    sessions: CodexSessionStore,
    anchorScreenPoint: CGPoint?
  ) {
    state.update(deck: deck, selectedSlideID: selectedSlideID, baseURL: baseURL)
    state.fallbackSlideIndex = state.clampedSlideIndex(fallbackSlideIndex)

    if window == nil || self.sessions !== sessions {
      makeWindow(sessions: sessions, anchorScreenPoint: anchorScreenPoint)
    } else if let anchorScreenPoint, window?.isVisible != true {
      positionWindow(near: anchorScreenPoint)
    }

    self.sessions = sessions
    isPresented = true
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func update(deck: PresentationDeck, selectedSlideID: Slide.ID?, baseURL: URL?) {
    guard window != nil else { return }
    state.update(deck: deck, selectedSlideID: selectedSlideID, baseURL: baseURL)
  }

  func dismiss() {
    guard let window else { return }
    self.window = nil
    isPresented = false
    window.close()
  }

  private func makeWindow(sessions: CodexSessionStore, anchorScreenPoint: CGPoint?) {
    window?.close()

    let contentSize = NSSize(width: 520, height: 292.5)
    let screen = screen(containing: anchorScreenPoint) ?? NSApp.keyWindow?.screen ?? NSScreen.main
    let frame = initialFrame(contentSize: contentSize, near: anchorScreenPoint, on: screen)
    let window = PresentationPreviewWindow(
      contentRect: frame,
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false,
      screen: screen
    )

    window.isReleasedWhenClosed = false
    window.title = "Slide Preview"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = true
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.isMovableByWindowBackground = true
    window.contentAspectRatio = NSSize(width: 16, height: 9)
    window.contentMinSize = NSSize(width: 260, height: 146.25)
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.contentViewController = NSHostingController(
      rootView: PresentationPreviewWindowContent(
        state: state,
        sessions: sessions,
        onClose: { [weak self] in
          self?.dismiss()
        }
      )
    )
    window.onClose = { [weak self] in
      self?.window = nil
      self?.isPresented = false
    }

    self.sessions = sessions
    self.window = window
  }

  private func positionWindow(near point: CGPoint) {
    guard let window else { return }
    let screen = screen(containing: point) ?? window.screen ?? NSScreen.main
    let frame = initialFrame(contentSize: window.contentLayoutRect.size, near: point, on: screen)
    window.setFrame(frame, display: true)
  }

  private func initialFrame(contentSize: NSSize, near point: CGPoint?, on screen: NSScreen?) -> NSRect {
    let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
    let anchor = point ?? CGPoint(x: visibleFrame.midX, y: visibleFrame.midY)
    let proposedOrigin = CGPoint(
      x: anchor.x - 32,
      y: anchor.y - contentSize.height / 2
    )
    let origin = CGPoint(
      x: min(max(proposedOrigin.x, visibleFrame.minX + 20), visibleFrame.maxX - contentSize.width - 20),
      y: min(max(proposedOrigin.y, visibleFrame.minY + 20), visibleFrame.maxY - contentSize.height - 20)
    )
    return NSRect(origin: origin, size: contentSize)
  }

  private func screen(containing point: CGPoint?) -> NSScreen? {
    guard let point else { return nil }
    return NSScreen.screens.first { $0.frame.contains(point) }
  }
}
