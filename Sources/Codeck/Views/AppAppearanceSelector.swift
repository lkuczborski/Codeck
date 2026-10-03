import AppKit
import SwiftUI

struct AppAppearanceSelector: View {
    @Binding var selection: AppAppearanceMode

    var body: some View {
        NativeAppearancePicker(selection: $selection)
            .fixedSize()
            .help("Choose app appearance")
    }
}

struct NativeAppearancePicker: NSViewRepresentable {
    @Binding var selection: AppAppearanceMode

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.segmentCount = AppAppearanceMode.allCases.count
        control.trackingMode = .selectOne
        control.controlSize = .small
        control.segmentStyle = .automatic
        control.setAccessibilityLabel("Appearance")
        if #available(macOS 26.0, *) {
            control.borderShape = .capsule
        }
        #if compiler(>=6.4)
            if #available(macOS 27.0, *) {
                control.role = .tabs
            }
        #endif
        for (index, mode) in AppAppearanceMode.allCases.enumerated() {
            control.setToolTip(mode.title, forSegment: index)
            control.setWidth(20, forSegment: index)
        }
        control.target = context.coordinator
        control.action = #selector(Coordinator.selectAppearance(_:))
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.selection = $selection
        control.selectedSegment = AppAppearanceMode.allCases.firstIndex(of: selection) ?? 0
        for (index, mode) in AppAppearanceMode.allCases.enumerated() {
            let color: NSColor = mode == selection ? .controlAccentColor : .labelColor
            let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
                .applying(.init(paletteColors: [color]))
            let image = NSImage(systemSymbolName: mode.systemImage, accessibilityDescription: mode.title)?
                .withSymbolConfiguration(configuration)
            image?.isTemplate = false
            control.setImage(image, forSegment: index)
        }
    }

    func sizeThatFits(_: ProposedViewSize, nsView: NSSegmentedControl, context _: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }

    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<AppAppearanceMode>

        init(selection: Binding<AppAppearanceMode>) {
            self.selection = selection
        }

        @objc func selectAppearance(_ sender: NSSegmentedControl) {
            let modes = AppAppearanceMode.allCases
            guard modes.indices.contains(sender.selectedSegment) else { return }
            selection.wrappedValue = modes[sender.selectedSegment]
        }
    }
}
