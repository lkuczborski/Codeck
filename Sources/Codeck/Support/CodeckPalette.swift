import AppKit
import SwiftUI

enum CodeckPalette {
    static var workspace: Color {
        Color(nsColor: workspaceNSColor)
    }

    static var editor: Color {
        Color(nsColor: editorNSColor)
    }

    static var surface: Color {
        Color(nsColor: surfaceNSColor)
    }

    static var elevatedSurface: Color {
        Color(nsColor: elevatedSurfaceNSColor)
    }

    static var border: Color {
        Color(nsColor: borderNSColor)
    }

    static var separator: Color {
        Color(nsColor: separatorNSColor)
    }

    static let workspaceNSColor = adaptiveColor(
        light: NSColor(red: 0.949, green: 0.957, blue: 0.965, alpha: 1),
        dark: NSColor(red: 0.110, green: 0.118, blue: 0.133, alpha: 1)
    )

    static let editorNSColor = adaptiveColor(
        light: NSColor(red: 0.980, green: 0.984, blue: 0.988, alpha: 1),
        dark: NSColor(red: 0.110, green: 0.114, blue: 0.125, alpha: 1)
    )

    static let surfaceNSColor = adaptiveColor(
        light: NSColor(red: 0.925, green: 0.937, blue: 0.949, alpha: 1),
        dark: NSColor(red: 0.145, green: 0.157, blue: 0.176, alpha: 1)
    )

    static let elevatedSurfaceNSColor = adaptiveColor(
        light: NSColor(red: 0.890, green: 0.906, blue: 0.925, alpha: 1),
        dark: NSColor(red: 0.180, green: 0.192, blue: 0.216, alpha: 1)
    )

    static let borderNSColor = adaptiveColor(
        light: NSColor(red: 0.780, green: 0.808, blue: 0.835, alpha: 1),
        dark: NSColor(red: 0.275, green: 0.302, blue: 0.337, alpha: 1)
    )

    static let separatorNSColor = adaptiveColor(
        light: NSColor(red: 0.710, green: 0.737, blue: 0.765, alpha: 1),
        dark: NSColor(red: 0.235, green: 0.259, blue: 0.290, alpha: 1)
    )

    static let inlineCodeBackgroundNSColor = adaptiveColor(
        light: NSColor(red: 0.890, green: 0.906, blue: 0.925, alpha: 1),
        dark: NSColor(red: 0.170, green: 0.180, blue: 0.200, alpha: 1)
    )

    private static func adaptiveColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        }
    }
}
