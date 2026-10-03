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
                    .clipShape(.rect(cornerRadius: 6))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .padding(8)
                }
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
        .padding(4)
        .multilineTextAlignment(.leading)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
