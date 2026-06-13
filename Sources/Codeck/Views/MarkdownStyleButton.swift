import CodeckCore
import SwiftUI

struct MarkdownStyleButton: View {
    let style: MarkdownTextStyle
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            styledLabel
                .frame(width: 26, height: 24)
                .codeckControlSurface(isActive: isActive)
        }
        .buttonStyle(.plain)
        .help(style.help)
        .accessibilityLabel(style.title)
    }

    @ViewBuilder
    private var styledLabel: some View {
        let base = Text("a")
            .font(.system(size: 15, weight: .regular))

        switch style {
        case .bold:
            base.bold()
        case .italic:
            base.italic()
        case .inlineCode:
            base
                .font(.system(size: 14, design: .monospaced))
                .padding(.horizontal, 3)
                .background(CodeckPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        case .strikethrough:
            base.strikethrough()
        case .link:
            base.underline()
        }
    }
}
