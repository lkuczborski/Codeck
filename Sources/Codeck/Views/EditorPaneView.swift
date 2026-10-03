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
                themePicker

                editorControls

                Spacer(minLength: 10)

                deckSettingsButton
            }
            .frame(height: CodeckInterfaceMetrics.paneHeaderHeight)

            HStack(spacing: 8) {
                compactThemePicker

                editorControls

                Spacer(minLength: 0)

                deckSettingsButton
            }
            .frame(height: CodeckInterfaceMetrics.paneHeaderHeight)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    themePicker
                    Spacer(minLength: 0)
                    deckSettingsButton
                }

                editorControls
            }
            .padding(.vertical, 6)
        }
        .controlSize(.small)
        .codeckNativeGlassGrouping()
        .padding(.horizontal, CodeckInterfaceMetrics.editorContentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editorBackground: Color {
        CodeckPalette.editor
    }

    private var themePicker: some View {
        Menu {
            Picker("Theme", selection: $settings.theme) {
                ForEach(PresentationTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Text(settings.theme.displayName)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .help("Presentation theme")
        .padding(.horizontal, 8)
        .frame(height: CodeckInterfaceMetrics.toolbarControlHeight)
        .codeckNativeControlBar()
        .fixedSize()
    }

    private var compactThemePicker: some View {
        themePicker
    }

    private var editorControls: some View {
        HStack(spacing: 8) {
            insertMenu.labelStyle(.iconOnly)
            toolbarSeparator
            formatButtons
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
        .frame(height: CodeckInterfaceMetrics.toolbarControlHeight)
        .codeckNativeControlBar()
        .fixedSize(horizontal: true, vertical: false)
    }

    private var formatButtons: some View {
        ForEach(MarkdownTextStyle.allCases) { style in
            MarkdownStyleButton(
                style: style,
                isActive: editorController.activeStyles.contains(style),
                action: { editorController.toggle(style) }
            )
        }
    }

    private var toolbarSeparator: some View {
        Divider()
            .frame(height: 14)
            .accessibilityHidden(true)
    }

    private var deckSettingsButton: some View {
        Button {
            showsDeckSettings.toggle()
        } label: {
            Label("Deck Settings", systemImage: "slider.horizontal.3")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("Edit deck-level Codex settings")
        .padding(.horizontal, 8)
        .frame(height: CodeckInterfaceMetrics.toolbarControlHeight)
        .codeckNativeControlBar()
        .popover(isPresented: $showsDeckSettings, arrowEdge: .bottom) {
            DeckSettingsPopover(settings: $settings, modelCatalog: modelCatalog)
        }
        .fixedSize()
    }

    private var insertMenu: some View {
        Menu {
            Section("Text") {
                ForEach([MarkdownInsertion.heading1, .heading2, .heading3, .paragraph, .link]) { insertion in
                    insertButton(insertion)
                }
            }
            Section("Blocks") {
                ForEach([MarkdownInsertion.bulletedList, .numberedList, .blockquote, .table, .horizontalRule]) { insertion in
                    insertButton(insertion)
                }
            }
            Section("Media and Code") {
                ForEach([MarkdownInsertion.image, .codeBlock, .codexSession]) { insertion in
                    insertButton(insertion)
                }
            }
        } label: {
            Label("Insert", systemImage: "plus")
        }
        .menuStyle(.button)
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
