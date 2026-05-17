import CodeckCore
import SwiftUI

struct SlideTemplatePickerView: View {
  let theme: PresentationTheme
  let onCancel: () -> Void
  let onInsert: (SlideTemplate) -> Void

  @State private var selectedTemplateID = SlideTemplateCatalog.defaultTemplate?.id

  private var selectedTemplate: SlideTemplate? {
    selectedTemplateID.flatMap(SlideTemplateCatalog.template(withID:))
  }

  private let columns = [
    GridItem(.adaptive(minimum: 230, maximum: 300), spacing: 16)
  ]

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 22) {
          ForEach(SlideTemplateCatalog.sections) { section in
            templateSection(section)
          }
        }
        .padding(20)
      }

      Divider()

      footer
    }
    .frame(minWidth: 720, idealWidth: 820, minHeight: 540, idealHeight: 640)
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text("New Slide from Template")
          .font(.headline)

        Text("Choose a rendered starting point for the next slide.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
  }

  private func templateSection(_ section: SlideTemplateSection) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(section.title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)

      LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
        ForEach(section.templates) { template in
          Button {
            selectedTemplateID = template.id
          } label: {
            SlideTemplateCard(
              template: template,
              theme: theme,
              isSelected: selectedTemplateID == template.id
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var footer: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(selectedTemplate?.name ?? "No Template Selected")
          .font(.subheadline.weight(.semibold))

        Text(selectedTemplate?.description ?? "Select a template preview to continue.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button("Cancel", role: .cancel, action: onCancel)
        .keyboardShortcut(.cancelAction)

      Button("Create Slide") {
        if let selectedTemplate {
          onInsert(selectedTemplate)
        }
      }
      .keyboardShortcut(.defaultAction)
      .disabled(selectedTemplate == nil)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }
}

private struct SlideTemplateCard: View {
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
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.16), lineWidth: 1)
    }
  }
}
