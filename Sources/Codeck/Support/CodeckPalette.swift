import AppKit
import SwiftUI

enum CodeckPalette {
    static var editor: Color {
        Color(nsColor: editorNSColor)
    }

    static let editorNSColor = NSColor.textBackgroundColor
    static let inlineCodeBackgroundNSColor = NSColor.quaternaryLabelColor
}
