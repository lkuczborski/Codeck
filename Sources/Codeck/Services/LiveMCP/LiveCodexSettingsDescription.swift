import CodeckCore
import Foundation

struct LiveCodexSettingsDescription: Encodable {
  let model: String
  let reasoning: String
  let sandbox: String

  init(_ settings: DeckCodexSettings) {
    model = settings.model
    reasoning = settings.reasoning.rawValue
    sandbox = settings.sandbox
  }
}
