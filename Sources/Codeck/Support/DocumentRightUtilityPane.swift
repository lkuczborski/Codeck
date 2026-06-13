import CodeckCore
import SwiftUI

enum DocumentRightUtilityPane: String, CaseIterable, Identifiable {
    case preview
    case assistant

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .preview:
            "Preview"
        case .assistant:
            "Assistant"
        }
    }

    var systemImage: String {
        switch self {
        case .preview:
            "play.rectangle"
        case .assistant:
            "sparkles"
        }
    }
}
