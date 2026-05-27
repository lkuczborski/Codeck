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

@MainActor
private final class PresentationPreviewWindowState: ObservableObject {
  @Published var deck: PresentationDeck = .blank
  @Published var selectedSlideID: Slide.ID?
  @Published var fallbackSlideIndex: Int?
  @Published var baseURL: URL?

  func update(deck: PresentationDeck, selectedSlideID: Slide.ID?, baseURL: URL?) {
    let didChangeSelection = self.selectedSlideID != selectedSlideID
    self.deck = deck
    self.selectedSlideID = selectedSlideID
    self.baseURL = baseURL

    if didChangeSelection {
      fallbackSlideIndex = nil
    } else {
      fallbackSlideIndex = clampedSlideIndex(fallbackSlideIndex)
    }
  }

  func clampedSlideIndex(_ index: Int?) -> Int? {
    guard let index, deck.slides.indices.contains(index) else { return nil }
    return index
  }
}

private struct PresentationPreviewWindowContent: View {
  @ObservedObject var state: PresentationPreviewWindowState
  @ObservedObject var sessions: CodexSessionStore
  let onClose: () -> Void

  @State private var skimmedSlideIndex: Int?
  @State private var isHovered = false

  var body: some View {
    ZStack {
      PresentationSlidePreviewView(
        deck: state.deck,
        selectedSlideID: state.selectedSlideID,
        sessions: sessions,
        baseURL: state.baseURL,
        fallbackSlideIndex: state.fallbackSlideIndex,
        skimmedSlideIndex: $skimmedSlideIndex,
        isChromeVisible: isHovered,
        handlesScrubbing: false,
        showsShadow: false
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      PresentationPreviewWindowInteractionLayer(
        slideCount: state.deck.slides.count,
        skimmedSlideIndex: $skimmedSlideIndex,
        isHovered: $isHovered
      )

      GeometryReader { proxy in
        let slideRect = slideRect(in: proxy.size)

        closeButton
          .opacity(isHovered ? 1 : 0)
          .position(x: slideRect.maxX - 20, y: slideRect.minY + 20)
          .animation(.easeOut(duration: 0.12), value: isHovered)
      }
      .allowsHitTesting(isHovered)
    }
    .onHover { hovering in
      isHovered = hovering
      if !hovering {
        skimmedSlideIndex = nil
      }
    }
    .onChange(of: state.deck.slides) { _, _ in
      skimmedSlideIndex = state.clampedSlideIndex(skimmedSlideIndex)
      state.fallbackSlideIndex = state.clampedSlideIndex(state.fallbackSlideIndex)
    }
    .onChange(of: state.selectedSlideID) { _, _ in
      skimmedSlideIndex = nil
    }
  }

  private var closeButton: some View {
    Button(action: onClose) {
      Image(systemName: "xmark")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 24, height: 24)
        .background(.black.opacity(0.62), in: Circle())
    }
    .buttonStyle(.plain)
  }

  private func slideRect(in size: CGSize) -> CGRect {
    let aspectRatio = 16.0 / 9.0
    guard size.width > 0, size.height > 0 else { return .zero }

    let availableAspectRatio = size.width / size.height
    if availableAspectRatio > aspectRatio {
      let width = size.height * aspectRatio
      return CGRect(
        x: (size.width - width) / 2,
        y: 0,
        width: width,
        height: size.height
      )
    }

    let height = size.width / aspectRatio
    return CGRect(
      x: 0,
      y: (size.height - height) / 2,
      width: size.width,
      height: height
    )
  }
}

private struct PresentationPreviewWindowInteractionLayer: NSViewRepresentable {
  let slideCount: Int
  @Binding var skimmedSlideIndex: Int?
  @Binding var isHovered: Bool

  func makeNSView(context: Context) -> InteractionView {
    InteractionView()
  }

  func updateNSView(_ view: InteractionView, context: Context) {
    view.onMouseMoved = { point, size in
      isHovered = true
      guard slideCount > 1, size.width > 0 else {
        skimmedSlideIndex = nil
        return
      }

      let clampedX = min(max(point.x, 0), size.width)
      let rawIndex = Int((clampedX / size.width) * CGFloat(slideCount))
      skimmedSlideIndex = min(max(rawIndex, 0), slideCount - 1)
    }
    view.onMouseExited = {
      skimmedSlideIndex = nil
    }
  }

  final class InteractionView: NSView {
    var onMouseMoved: ((CGPoint, CGSize) -> Void)?
    var onMouseExited: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private let resizeCornerSize: CGFloat = 34
    private let aspectRatio: CGFloat = 16.0 / 9.0
    private let minimumFrameWidth: CGFloat = 260

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
      true
    }

    override func updateTrackingAreas() {
      if let trackingArea {
        removeTrackingArea(trackingArea)
      }

      let area = NSTrackingArea(
        rect: bounds,
        options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
        owner: self
      )
      addTrackingArea(area)
      trackingArea = area

      super.updateTrackingAreas()
    }

    override func resetCursorRects() {
      super.resetCursorRects()

      for corner in ResizeCorner.allCases {
        addCursorRect(corner.rect(in: bounds, size: resizeCornerSize), cursor: corner.cursor)
      }
    }

    override func mouseMoved(with event: NSEvent) {
      updatePointerState(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
      updatePointerState(with: event)
    }

    override func mouseExited(with event: NSEvent) {
      onMouseExited?()
    }

    override func mouseDown(with event: NSEvent) {
      let point = convert(event.locationInWindow, from: nil)
      if let corner = resizeCorner(at: point) {
        resizeWindow(from: corner, with: event)
        return
      }

      window?.performDrag(with: event)
    }

    private func updatePointerState(with event: NSEvent) {
      let point = convert(event.locationInWindow, from: nil)
      onMouseMoved?(point, bounds.size)

      if let corner = resizeCorner(at: point) {
        corner.cursor.set()
      } else {
        NSCursor.arrow.set()
      }
    }

    private func resizeCorner(at point: CGPoint) -> ResizeCorner? {
      ResizeCorner.allCases.first { $0.rect(in: bounds, size: resizeCornerSize).contains(point) }
    }

    private func resizeWindow(from corner: ResizeCorner, with event: NSEvent) {
      guard let window else { return }

      let initialFrame = window.frame
      let initialMouse = window.convertPoint(toScreen: event.locationInWindow)

      while true {
        guard let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else {
          continue
        }

        if nextEvent.type == .leftMouseUp {
          break
        }

        let mouse = window.convertPoint(toScreen: nextEvent.locationInWindow)
        let horizontalDelta = corner.resizesRight ? mouse.x - initialMouse.x : initialMouse.x - mouse.x
        let verticalDelta = corner.resizesTop ? mouse.y - initialMouse.y : initialMouse.y - mouse.y
        let verticalDeltaAsWidth = verticalDelta * aspectRatio
        let dominantDelta = abs(horizontalDelta) >= abs(verticalDeltaAsWidth) ? horizontalDelta : verticalDeltaAsWidth
        let width = max(minimumFrameWidth, initialFrame.width + dominantDelta)
        let height = width / aspectRatio

        window.setFrame(corner.frame(from: initialFrame, width: width, height: height), display: true)
      }
    }

    private enum ResizeCorner: CaseIterable {
      case topLeft
      case topRight
      case bottomLeft
      case bottomRight

      var resizesRight: Bool {
        self == .topRight || self == .bottomRight
      }

      var resizesTop: Bool {
        self == .topLeft || self == .topRight
      }

      var cursor: NSCursor {
        if #available(macOS 15.0, *) {
          return NSCursor.frameResize(position: cursorPosition, directions: .all)
        }

        return .arrow
      }

      @available(macOS 15.0, *)
      private var cursorPosition: NSCursor.FrameResizePosition {
        switch self {
        case .topLeft:
          .topLeft
        case .topRight:
          .topRight
        case .bottomLeft:
          .bottomLeft
        case .bottomRight:
          .bottomRight
        }
      }

      func rect(in bounds: CGRect, size: CGFloat) -> CGRect {
        switch self {
        case .topLeft:
          CGRect(x: bounds.minX, y: bounds.maxY - size, width: size, height: size)
        case .topRight:
          CGRect(x: bounds.maxX - size, y: bounds.maxY - size, width: size, height: size)
        case .bottomLeft:
          CGRect(x: bounds.minX, y: bounds.minY, width: size, height: size)
        case .bottomRight:
          CGRect(x: bounds.maxX - size, y: bounds.minY, width: size, height: size)
        }
      }

      func frame(from initialFrame: CGRect, width: CGFloat, height: CGFloat) -> CGRect {
        switch self {
        case .topLeft:
          CGRect(x: initialFrame.maxX - width, y: initialFrame.minY, width: width, height: height)
        case .topRight:
          CGRect(x: initialFrame.minX, y: initialFrame.minY, width: width, height: height)
        case .bottomLeft:
          CGRect(x: initialFrame.maxX - width, y: initialFrame.maxY - height, width: width, height: height)
        case .bottomRight:
          CGRect(x: initialFrame.minX, y: initialFrame.maxY - height, width: width, height: height)
        }
      }
    }
  }
}

private final class PresentationPreviewWindow: NSWindow {
  var onClose: (() -> Void)?
  private var isClosing = false

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func close() {
    guard !isClosing else { return }
    isClosing = true

    let closeHandler = onClose
    onClose = nil

    super.close()
    closeHandler?()
  }
}
