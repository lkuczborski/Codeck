import CodeckCore
import SwiftUI

struct DocumentRightUtilityActions {
    let isVisible: Bool
    let mode: DocumentRightUtilityPane
    let togglePreview: () -> Void
    let toggleAssistant: () -> Void

    var isPreviewActive: Bool {
        isVisible && mode == .preview
    }

    var isAssistantActive: Bool {
        isVisible && mode == .assistant
    }
}
