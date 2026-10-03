import AppKit
import SwiftUI

struct NativeHoverPopover<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    let contentSize: CGSize
    let content: Content

    func makeNSView(context _: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ anchor: NSView, context: Context) {
        context.coordinator.update(anchor: anchor, isPresented: $isPresented, contentSize: contentSize, content: content)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, contentSize: contentSize, content: content)
    }

    static func dismantleNSView(_: NSView, coordinator: Coordinator) {
        coordinator.popover.delegate = nil
        coordinator.popover.close()
    }

    @MainActor
    final class Coordinator: NSObject, NSPopoverDelegate {
        let popover = NSPopover()
        private let hostingController: NSHostingController<Content>
        private var isPresented: Binding<Bool>

        init(isPresented: Binding<Bool>, contentSize: CGSize, content: Content) {
            self.isPresented = isPresented
            hostingController = NSHostingController(rootView: content)
            super.init()
            hostingController.sizingOptions = []
            hostingController.view.setFrameSize(contentSize)
            hostingController.preferredContentSize = contentSize
            // A hover preview must let the first click reach the underlying toolbar.
            popover.behavior = .applicationDefined
            popover.animates = true
            popover.contentViewController = hostingController
            popover.contentSize = contentSize
            popover.delegate = self
        }

        func update(anchor: NSView, isPresented: Binding<Bool>, contentSize: CGSize, content: Content) {
            self.isPresented = isPresented
            hostingController.rootView = content
            if popover.contentSize != contentSize {
                hostingController.preferredContentSize = contentSize
                popover.contentSize = contentSize
            }
            if isPresented.wrappedValue {
                guard anchor.window != nil, !popover.isShown else { return }
                popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
            } else if popover.isShown {
                popover.close()
            }
        }

        func popoverDidClose(_: Notification) {
            if isPresented.wrappedValue {
                isPresented.wrappedValue = false
            }
        }
    }
}
