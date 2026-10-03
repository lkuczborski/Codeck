import CodeckCore
import SwiftUI

struct MarkdownStyleButton: View {
    let style: MarkdownTextStyle
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isActive }, set: { _ in action() })) {
            Label(style.title, systemImage: systemImage)
        }
        .toggleStyle(.button)
        .labelStyle(.iconOnly)
        .help(style.help)
        .accessibilityLabel(style.title)
    }

    private var systemImage: String {
        switch style {
        case .bold: "bold"
        case .italic: "italic"
        case .inlineCode: "chevron.left.forwardslash.chevron.right"
        case .strikethrough: "strikethrough"
        case .link: "link"
        }
    }
}
