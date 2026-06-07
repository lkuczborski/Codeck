import Foundation

public struct PresentationSettings: Hashable, Sendable {
  public var theme: PresentationTheme
  public var codex: DeckCodexSettings

  public static let `default` = PresentationSettings(
    theme: .studio,
    codex: .default
  )

  public init(theme: PresentationTheme, codex: DeckCodexSettings) {
    self.theme = theme
    self.codex = codex
  }
}
