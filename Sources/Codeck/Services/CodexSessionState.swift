import CodeckCore
import Foundation
import SwiftUI

enum CodexSessionState: String, Hashable {
    case idle
    case running
    case completed
    case failed
    case stopped
}
