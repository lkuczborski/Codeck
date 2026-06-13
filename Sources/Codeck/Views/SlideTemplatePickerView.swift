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
        GridItem(.adaptive(minimum: 230, maximum: 300), spacing: 16),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .codeckDivider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(SlideTemplateCatalog.sections) { section in
                        templateSection(section)
                    }
                }
                .padding(20)
            }

            Divider()
                .codeckDivider()

            footer
        }
        .frame(minWidth: 720, idealWidth: 820, minHeight: 540, idealHeight: 640)
        .codeckWorkspaceBackground()
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
