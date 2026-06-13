import AppKit
import CodeckCore
import SwiftUI

struct PresentationPreviewWindowInteractionLayer: NSViewRepresentable {
    let slideCount: Int
    @Binding var skimmedSlideIndex: Int?
    @Binding var isHovered: Bool

    func makeNSView(context _: Context) -> InteractionView {
        InteractionView()
    }

    func updateNSView(_ view: InteractionView, context _: Context) {
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

        override var acceptsFirstResponder: Bool {
            true
        }

        override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
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

        override func mouseExited(with _: NSEvent) {
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
