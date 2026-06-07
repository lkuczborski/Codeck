import CodeckCore
import Foundation
import SwiftUI

struct CodexSessionOutput: Hashable {
  var state: CodexSessionState
  var text: String
  var standardOutput: String
  var standardError: String

  init(
    state: CodexSessionState,
    text: String,
    standardOutput: String = "",
    standardError: String = ""
  ) {
    self.state = state
    self.text = text
    self.standardOutput = standardOutput
    self.standardError = standardError
  }
}
