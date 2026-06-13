import AppKit
import SwiftUI

final class MarkdownEditorController: ObservableObject {
    @Published var activeStyles: Set<MarkdownTextStyle> = []
    @Published var selection = NSRange(location: 0, length: 0)
    @Published private(set) var commandVersion = 0

    var pendingCommand: MarkdownEditorCommand?

    func insert(_ insertion: MarkdownInsertion, codexBlockNumber: Int) {
        pendingCommand = .insert(insertion, codexBlockNumber: codexBlockNumber)
        commandVersion += 1
    }

    func toggle(_ style: MarkdownTextStyle) {
        pendingCommand = .toggle(style)
        commandVersion += 1
    }
}
