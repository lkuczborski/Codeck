import AppKit
import SwiftUI

final class MarkdownEditorController: ObservableObject {
  @Published var activeStyles: Set<MarkdownTextStyle> = []
  @Published var selection = NSRange(location: 0, length: 0)
  @Published private(set) var commandVersion = 0

  fileprivate var pendingCommand: MarkdownEditorCommand?

  func insert(_ insertion: MarkdownInsertion, codexBlockNumber: Int) {
    pendingCommand = .insert(insertion, codexBlockNumber: codexBlockNumber)
    commandVersion += 1
  }

  func toggle(_ style: MarkdownTextStyle) {
    pendingCommand = .toggle(style)
    commandVersion += 1
  }
}

fileprivate enum MarkdownEditorCommand {
  case insert(MarkdownInsertion, codexBlockNumber: Int)
  case toggle(MarkdownTextStyle)
}

struct MarkdownTextEditorView: NSViewRepresentable {
  @Binding var text: String
  @ObservedObject var controller: MarkdownEditorController

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true

    let textView = NSTextView()
    textView.string = text
    textView.delegate = context.coordinator
    textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
    textView.textColor = .labelColor
    textView.backgroundColor = .clear
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
    context.coordinator.textView = textView
    context.coordinator.publishState(for: textView)
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.text = $text

    guard let textView = context.coordinator.textView else { return }

    if textView.string != text, !context.coordinator.isApplyingCommand {
      let selection = textView.selectedRange()
      textView.string = text
      textView.setSelectedRange(MarkdownTextEditorView.clamped(selection, length: (text as NSString).length))
      context.coordinator.publishState(for: textView)
    }

    if context.coordinator.handledCommandVersion != controller.commandVersion,
       let command = controller.pendingCommand {
      context.coordinator.handledCommandVersion = controller.commandVersion
      context.coordinator.perform(command, in: textView)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, controller: controller)
  }

  private static func clamped(_ range: NSRange, length: Int) -> NSRange {
    let location = min(max(range.location, 0), length)
    let upperBound = min(max(range.location + range.length, location), length)
    return NSRange(location: location, length: upperBound - location)
  }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<String>
    private let controller: MarkdownEditorController
    weak var textView: NSTextView?
    var handledCommandVersion = 0
    var isApplyingCommand = false

    init(text: Binding<String>, controller: MarkdownEditorController) {
      self.text = text
      self.controller = controller
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      text.wrappedValue = textView.string
      publishState(for: textView)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      publishState(for: textView)
    }

    fileprivate func perform(_ command: MarkdownEditorCommand, in textView: NSTextView) {
      isApplyingCommand = true
      defer { isApplyingCommand = false }

      let result: MarkdownEditResult
      switch command {
      case let .insert(insertion, codexBlockNumber):
        result = MarkdownEditorOperation.insert(
          insertion,
          into: textView.string,
          selection: textView.selectedRange(),
          codexBlockNumber: codexBlockNumber
        )
      case let .toggle(style):
        result = MarkdownEditorOperation.toggle(
          style,
          in: textView.string,
          selection: textView.selectedRange()
        )
      }

      textView.string = result.text
      textView.setSelectedRange(result.selection)
      text.wrappedValue = result.text
      publishState(for: textView)
      textView.window?.makeFirstResponder(textView)
      textView.scrollRangeToVisible(result.selection)
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
  }
}
