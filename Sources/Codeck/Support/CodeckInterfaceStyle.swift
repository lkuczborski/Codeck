import SwiftUI

enum CodeckInterfaceMetrics {
    static let paneHeaderHeight: CGFloat = 40
    static let toolbarControlHeight: CGFloat = 24
    static let editorContentInset: CGFloat = 12
}

extension View {
    @ViewBuilder
    func codeckNativeBottomBar(@ViewBuilder content: () -> some View) -> some View {
        if #available(macOS 26.0, *) {
            safeAreaBar(edge: .bottom, spacing: 0, content: content)
        } else {
            safeAreaInset(edge: .bottom, spacing: 0, content: content)
        }
    }

    @ViewBuilder
    func codeckNativeGlassGrouping() -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { self }
        } else {
            self
        }
    }

    @ViewBuilder
    func codeckNativeControlBar() -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: .capsule)
        } else {
            background(.bar, in: .capsule)
        }
    }

    @ViewBuilder
    func codeckNativeNavigationPickerStyle() -> some View {
        #if compiler(>=6.4)
            if #available(macOS 27.0, *) {
                pickerStyle(.tabs)
            } else {
                pickerStyle(.segmented)
            }
        #else
            pickerStyle(.segmented)
        #endif
    }

    @ViewBuilder
    func codeckNativeButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else if prominent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }

    func codeckWorkspaceBackground() -> some View {
        background(.background)
    }
}
