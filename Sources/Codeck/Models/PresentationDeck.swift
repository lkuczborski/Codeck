import Foundation

struct PresentationDeck: Hashable {
  var settings: PresentationSettings
  var slides: [Slide]

  init(theme: PresentationTheme = .studio, slides: [Slide] = []) {
    self.settings = PresentationSettings(theme: theme, codex: .default)
    self.slides = slides.isEmpty ? [Slide(markdown: "# New Slide\n\nStart writing...")] : slides
  }

  init(settings: PresentationSettings = .default, slides: [Slide] = []) {
    self.settings = settings
    self.slides = slides.isEmpty ? [Slide(markdown: "# New Slide\n\nStart writing...")] : slides
  }

  init(markdownDocument: String) {
    let parsed = Self.parseMetadata(from: markdownDocument)
    settings = parsed.settings
    slides = Self.parseSlides(from: parsed.markdown)
    if slides.isEmpty {
      slides = [Slide(markdown: "# New Slide\n\nStart writing...")]
    }
  }

  var theme: PresentationTheme {
    get { settings.theme }
    set { settings.theme = newValue }
  }

  static var sample: PresentationDeck {
    PresentationDeck(
      theme: .studio,
      slides: [
        Slide(
          markdown:
            """
            # Prompting Codex Live

            Build lessons as Markdown slides. Use the preview to check tables, images, code, and live Codex sessions.

            | Slide part | Purpose |
            | --- | --- |
            | Markdown | Explain the concept |
            | Codex block | Demonstrate the prompt |
            | Theme | Match the classroom mood |
            """
        ),
        Slide(
          markdown:
            """
            # Live Codex Block

            Add a fenced `codex` block to run a prompt during the presentation.

            ```codex id=first-demo
            title: Show prompt-quality tactics

            Explain three practical ways to make a prompt more testable when asking Codex to change code.
            ```
            """
        ),
        Slide(
          markdown:
            """
            # Rich Markdown

            Images and gifs work with normal Markdown syntax:

            ![Local image example](Images/example.png)

            ```swift
            struct Lesson: Identifiable {
              let title: String
              let prompt: String
            }
            ```
            """
        )
      ]
    )
  }

  var markdownDocument: String {
    deckDocument
  }

  var deckDocument: String {
    var result = yamlHeader
    result += slides.map(\.markdown).joined(separator: "\n\n---\n\n")
    result += "\n"
    return result
  }

  private var yamlHeader: String {
    var lines = [
      "---",
      "format: codeck.mdeck",
      "version: 1",
      "theme: \(settings.theme.rawValue)",
      "codex:",
      "  sandbox: \(settings.codex.sandbox)",
      "  model: \(Self.yamlValue(settings.codex.model))",
      "  reasoning: \(settings.codex.reasoning.rawValue)"
    ]

    lines.append("---")
    lines.append("")
    return lines.joined(separator: "\n")
  }

  mutating func addSlide(after selectedID: Slide.ID?) -> Slide.ID {
    let slide = Slide(markdown: "# New Slide\n\nStart writing...")
    if let selectedID, let index = slides.firstIndex(where: { $0.id == selectedID }) {
      slides.insert(slide, at: min(index + 1, slides.count))
    } else {
      slides.append(slide)
    }
    return slide.id
  }

  mutating func duplicateSlide(_ selectedID: Slide.ID?) -> Slide.ID? {
    guard let selectedID, let index = slides.firstIndex(where: { $0.id == selectedID }) else {
      return nil
    }

    let copy = Slide(markdown: slides[index].markdown)
    slides.insert(copy, at: index + 1)
    return copy.id
  }

  mutating func deleteSlide(_ selectedID: Slide.ID?) -> Slide.ID? {
    guard slides.count > 1 else {
      return slides.first?.id
    }

    guard let selectedID, let index = slides.firstIndex(where: { $0.id == selectedID }) else {
      return slides.first?.id
    }

    slides.remove(at: index)
    return slides[min(index, slides.count - 1)].id
  }

  mutating func insertCodexBlock(into slideID: Slide.ID?) {
    guard let slideID, let index = slides.firstIndex(where: { $0.id == slideID }) else {
      return
    }

    let blockNumber = slides[index].codexBlocks.count + 1
    slides[index].markdown +=
      """


      ```codex id=demo-\(blockNumber)
      title: Describe the goal for this prompt

      Explain this concept with one concrete example.
      ```
      """
  }

  private static func parseMetadata(from rawMarkdown: String) -> (settings: PresentationSettings, markdown: String) {
    if let parsed = YAMLFrontMatter.parse(from: rawMarkdown) {
      return (settings(from: parsed.values), parsed.body)
    }

    var settings = PresentationSettings.default
    var lines = rawMarkdown.components(separatedBy: .newlines)

    while let first = lines.first, first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      lines.removeFirst()
    }

    if let first = lines.first {
      let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.hasPrefix("<!-- codeck-theme:"), trimmed.hasSuffix("-->") {
        let value = trimmed
          .replacingOccurrences(of: "<!-- codeck-theme:", with: "")
          .replacingOccurrences(of: "-->", with: "")
          .trimmingCharacters(in: .whitespacesAndNewlines)
        settings.theme = PresentationTheme(rawValue: value) ?? .studio
        lines.removeFirst()
      }
    }

    return (settings, lines.joined(separator: "\n"))
  }

  private static func settings(from values: [String: String]) -> PresentationSettings {
    let theme = values["theme"].flatMap(PresentationTheme.init(rawValue:)) ?? .studio
    let sandbox = nonEmpty(values["codex.sandbox"] ?? values["sandbox"]) ?? "read-only"
    let model = CodexModelOption.normalizedModelID(nonEmpty(values["codex.model"] ?? values["model"]))
    let reasoningValue = nonEmpty(values["codex.reasoning"] ?? values["reasoning"] ?? values["codex.reasoning_effort"] ?? values["reasoning_effort"])
    let reasoning = CodexModelOption.normalizedReasoning(
      reasoningValue.map(CodexReasoningEffort.init(rawValue:)),
      for: model
    )

    return PresentationSettings(
      theme: theme,
      codex: DeckCodexSettings(
        model: model,
        reasoning: reasoning,
        sandbox: sandbox
      )
    )
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }

  private static func yamlValue(_ value: String) -> String {
    let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
  }

  private static func parseSlides(from markdown: String) -> [Slide] {
    var slides: [Slide] = []
    var current: [String] = []
    var insideFence = false
    var fenceMarker = ""

    for line in markdown.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
        let marker = String(trimmed.prefix(3))
        if insideFence, marker == fenceMarker {
          insideFence = false
          fenceMarker = ""
        } else if !insideFence {
          insideFence = true
          fenceMarker = marker
        }
      }

      if !insideFence && trimmed == "---" {
        let markdown = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !markdown.isEmpty {
          slides.append(Slide(markdown: markdown))
        }
        current.removeAll()
      } else {
        current.append(line)
      }
    }

    let markdown = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    if !markdown.isEmpty {
      slides.append(Slide(markdown: markdown))
    }

    return slides
  }
}
