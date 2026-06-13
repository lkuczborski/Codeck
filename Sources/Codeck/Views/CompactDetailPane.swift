import AppKit
import CodeckCore
import SwiftUI

enum CompactDetailPane: String, CaseIterable, Identifiable {
    case editor
    case preview
    case assistant

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .editor:
            "Editor"
        case .preview:
            "Preview"
        case .assistant:
            "Assistant"
        }
    }

    var systemImage: String {
        switch self {
        case .editor:
            "pencil"
        case .preview:
            "play.rectangle"
        case .assistant:
            "sparkles"
        }
    }
}
