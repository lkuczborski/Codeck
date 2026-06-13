import AppKit
import SwiftUI

struct MarkdownTextEditorView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var controller: MarkdownEditorController
    let initialSelection: NSRange?
    let focusesInitially: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        text: Binding<String>,
        controller: MarkdownEditorController,
        initialSelection: NSRange? = nil,
        focusesInitially: Bool = false
    ) {
        _text = text
        self.controller = controller
        self.initialSelection = initialSelection
        self.focusesInitially = focusesInitially
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.string = text
        textView.delegate = context.coordinator
        textView.font = MarkdownEditorHighlighter.baseFont
        textView.textColor = .labelColor
        textView.drawsBackground = true
        textView.backgroundColor = CodeckPalette.editorNSColor
        textView.insertionPointColor = .controlAccentColor
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        context.coordinator.attach(textView)
        applyAppearance(to: scrollView, textView: textView)
        context.coordinator.applyHighlighting(to: textView)
        context.coordinator.applyInitialSelectionIfNeeded(to: textView)
        context.coordinator.publishState(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.initialSelection = initialSelection
        context.coordinator.focusesInitially = focusesInitially

        guard let textView = context.coordinator.textView else { return }
        applyAppearance(to: scrollView, textView: textView)

        if textView.string != text, !context.coordinator.isApplyingCommand {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(MarkdownTextEditorView.clamped(selection, length: (text as NSString).length))
            context.coordinator.applyHighlighting(to: textView)
            context.coordinator.publishState(for: textView)
        } else {
            context.coordinator.applyHighlighting(to: textView)
        }

        context.coordinator.applyInitialSelectionIfNeeded(to: textView)

        if context.coordinator.handledCommandVersion != controller.commandVersion,
           let command = controller.pendingCommand
        {
            context.coordinator.handledCommandVersion = controller.commandVersion
            context.coordinator.perform(command, in: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            controller: controller,
            initialSelection: initialSelection,
            focusesInitially: focusesInitially
        )
    }

    private static func clamped(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(range.location, 0), length)
        let upperBound = min(max(range.location + range.length, location), length)
        return NSRange(location: location, length: upperBound - location)
    }

    private func applyAppearance(to scrollView: NSScrollView, textView: NSTextView) {
        _ = colorScheme
        scrollView.appearance = nil
        scrollView.contentView.appearance = nil
        textView.appearance = nil
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.backgroundColor = CodeckPalette.editorNSColor
        textView.typingAttributes = MarkdownEditorHighlighter.baseTypingAttributes
        scrollView.drawsBackground = true
        scrollView.backgroundColor = CodeckPalette.editorNSColor
        scrollView.contentView.drawsBackground = true
        scrollView.contentView.backgroundColor = CodeckPalette.editorNSColor
        textView.drawsBackground = true
        let textRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.needsDisplay = true
        textView.layoutManager?.invalidateDisplay(forCharacterRange: textRange)
        scrollView.needsDisplay = true
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var initialSelection: NSRange?
        var focusesInitially: Bool
        private let controller: MarkdownEditorController
        weak var textView: NSTextView?
        var handledCommandVersion = 0
        var isApplyingCommand = false
        private var didApplyInitialSelection = false

        init(
            text: Binding<String>,
            controller: MarkdownEditorController,
            initialSelection: NSRange?,
            focusesInitially: Bool
        ) {
            self.text = text
            self.controller = controller
            self.initialSelection = initialSelection
            self.focusesInitially = focusesInitially
        }

        func attach(_ textView: NSTextView) {
            self.textView = textView
            didApplyInitialSelection = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            applyHighlighting(to: textView)
            publishState(for: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            publishState(for: textView)
        }

        fileprivate func perform(_ command: MarkdownEditorCommand, in textView: NSTextView) {
            isApplyingCommand = true
            defer { isApplyingCommand = false }

            let result: MarkdownEditResult = switch command {
            case let .insert(insertion, codexBlockNumber):
                MarkdownEditorOperation.insert(
                    insertion,
                    into: textView.string,
                    selection: textView.selectedRange(),
                    codexBlockNumber: codexBlockNumber
                )
            case let .toggle(style):
                MarkdownEditorOperation.toggle(
                    style,
                    in: textView.string,
                    selection: textView.selectedRange()
                )
            }

            textView.string = result.text
            textView.setSelectedRange(result.selection)
            applyHighlighting(to: textView)
            text.wrappedValue = result.text
            publishState(for: textView)
            textView.window?.makeFirstResponder(textView)
            textView.scrollRangeToVisible(result.selection)
        }

        func applyInitialSelectionIfNeeded(to textView: NSTextView) {
            guard !didApplyInitialSelection, let initialSelection else { return }

            let selection = MarkdownTextEditorView.clamped(
                initialSelection,
                length: (textView.string as NSString).length
            )
            textView.setSelectedRange(selection)
            publishState(for: textView)
            didApplyInitialSelection = true

            guard focusesInitially else { return }
            requestFocus(for: textView, selection: selection)
        }

        private func requestFocus(for textView: NSTextView, selection: NSRange, attemptsRemaining: Int = 5) {
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }

                textView.setSelectedRange(selection)
                if let window = textView.window {
                    window.makeFirstResponder(textView)
                    textView.scrollRangeToVisible(selection)
                } else if attemptsRemaining > 0 {
                    requestFocus(for: textView, selection: selection, attemptsRemaining: attemptsRemaining - 1)
                }
            }
        }

        func publishState(for textView: NSTextView) {
            let selection = textView.selectedRange()
            let activeStyles = MarkdownEditorOperation.activeStyles(in: textView.string, selection: selection)

            DispatchQueue.main.async { [weak controller] in
                guard let controller else { return }
                if controller.selection != selection {
                    controller.selection = selection
                }
                if controller.activeStyles != activeStyles {
                    controller.activeStyles = activeStyles
                }
            }
        }

        func applyHighlighting(to textView: NSTextView) {
            MarkdownEditorHighlighter.apply(to: textView)
        }
    }
}
