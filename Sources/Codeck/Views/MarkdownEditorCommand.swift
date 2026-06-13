import AppKit
import SwiftUI

enum MarkdownEditorCommand {
    case insert(MarkdownInsertion, codexBlockNumber: Int)
    case toggle(MarkdownTextStyle)
}
