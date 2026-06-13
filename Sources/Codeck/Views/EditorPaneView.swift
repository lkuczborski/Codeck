import CodeckCore
import SwiftUI

struct EditorPaneView: View {
    @Binding var slide: Slide
    @Binding var settings: PresentationSettings
    @ObservedObject var modelCatalog: CodexModelCatalogStore
    let appearanceRefreshID: UUID
    @StateObject private var editorController = MarkdownEditorController()
    @State private var showsDeckSettings = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            MarkdownTextEditorView(
                text: $slide.markdown,
                controller: editorController,
                initialSelection: initialEditorSelection,
                focusesInitially: initialEditorSelection != nil
            )
            .id(editorIdentity)
            .background(editorBackground)
        }
        .background(editorBackground)
    }

    private var initialEditorSelection: NSRange? {
        guard slide.markdown == PresentationDeck.defaultSlideMarkdown else { return nil }
        return NSRange(location: PresentationDeck.defaultSlideCursorLocation, length: 0)
    }

    private var editorIdentity: String {
        let scheme = colorScheme == .dark ? "dark" : "light"
        return "\(slide.id.uuidString)-\(appearanceRefreshID.uuidString)-\(scheme)"
    }

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                themePicker(width: 232)

                toolbarSeparator

                editorControls(labelStyle: .titleAndIcon)

                Spacer(minLength: 10)

                deckSettingsButton
                    .labelStyle(.titleAndIcon)
            }

            HStack(spacing: 8) {
                themePicker(width: 216)

                toolbarSeparator

                editorControls(labelStyle: .iconOnly)

                Spacer(minLength: 8)

                deckSettingsButton
                    .labelStyle(.iconOnly)
            }
        }
        .padding(10)
        .codeckGlassSurface(cornerRadius: 16, interactive: true)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var editorBackground: Color {
        CodeckPalette.editor
    }

    private func themePicker(width: CGFloat) -> some View {
        Picker("Theme", selection: $settings.theme) {
            ForEach(PresentationTheme.allCases) { theme in
                Text(theme.displayName).tag(theme)
            }
        }
        .pickerStyle(.menu)
        .fixedSize(horizontal: true, vertical: false)
        .frame(width: width, alignment: .leading)
        .layoutPriority(1)
    }

    private func editorControls(labelStyle: EditorToolbarLabelStyle) -> some View {
        HStack(spacing: 8) {
            switch labelStyle {
            case .titleAndIcon:
                insertMenu
                    .labelStyle(.titleAndIcon)
            case .iconOnly:
                insertMenu
                    .labelStyle(.iconOnly)
            }

            toolbarSeparator

            formatButtons
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var formatButtons: some View {
        HStack(spacing: 4) {
            ForEach(MarkdownTextStyle.allCases) { style in
                MarkdownStyleButton(
                    style: style,
                    isActive: editorController.activeStyles.contains(style),
                    action: { editorController.toggle(style) }
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
    }

    private var toolbarSeparator: some View {
        Rectangle()
            .fill(CodeckPalette.separator)
            .frame(width: 1, height: 24)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }

    private var deckSettingsButton: some View {
        Button {
            showsDeckSettings.toggle()
        } label: {
            Label("Deck Settings", systemImage: "slider.horizontal.3")
        }
        .codeckGlassButtonStyle()
        .help("Edit deck-level Codex settings")
        .popover(isPresented: $showsDeckSettings, arrowEdge: .bottom) {
            DeckSettingsPopover(settings: $settings, modelCatalog: modelCatalog)
        }
    }

    private var insertMenu: some View {
        Menu {
            Section("Text") {
                insertButton(.heading1)
                insertButton(.heading2)
                insertButton(.heading3)
                insertButton(.paragraph)
                insertButton(.link)
            }

            Section("Blocks") {
                insertButton(.bulletedList)
                insertButton(.numberedList)
                insertButton(.blockquote)
                insertButton(.table)
                insertButton(.horizontalRule)
            }

            Section("Media and Code") {
                insertButton(.image)
                insertButton(.codeBlock)
                insertButton(.codexSession)
            }
        } label: {
            Label("Insert", systemImage: "plus")
        }
        .codeckGlassButtonStyle(prominent: true)
        .help("Insert Markdown element")
    }

    private func insertButton(_ insertion: MarkdownInsertion) -> some View {
        Button {
            editorController.insert(insertion, codexBlockNumber: slide.codexBlocks.count + 1)
        } label: {
            Label(insertion.title, systemImage: insertion.systemImage)
        }
    }
}
