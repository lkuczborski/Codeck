import CodeckCore
import SwiftUI

struct SlideTemplateCard: View {
    let template: SlideTemplate
    let theme: PresentationTheme
    let isSelected: Bool

    private var previewHTML: String {
        MarkdownRenderer.templatePreviewHTMLDocument(
            for: Slide(markdown: template.markdown),
            theme: theme
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                MarkdownWebView(html: previewHTML, baseURL: nil)
                    .allowsHitTesting(false)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .padding(8)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.22), lineWidth: isSelected ? 2 : 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(template.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .codeckElevatedSurface(cornerRadius: 8)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.45) : CodeckPalette.border, lineWidth: 1)
        }
    }
}
