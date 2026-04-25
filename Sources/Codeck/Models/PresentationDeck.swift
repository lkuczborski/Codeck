import Foundation

struct PresentationDeck: Hashable {
  var theme: PresentationTheme
  var slides: [Slide]

  init(theme: PresentationTheme = .studio, slides: [Slide] = []) {
    self.theme = theme
    self.slides = slides.isEmpty ? [Slide(markdown: "# New Slide\n\nStart writing...")] : slides
  }

  init(markdownDocument: String) {
    let parsed = Self.parseMetadata(from: markdownDocument)
    theme = parsed.theme
    slides = Self.parseSlides(from: parsed.markdown)
    if slides.isEmpty {
      slides = [Slide(markdown: "# New Slide\n\nStart writing...")]
    }
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
            sandbox: read-only

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
    var result = "<!-- codeck-theme: \(theme.rawValue) -->\n\n"
    result += slides.map(\.markdown).joined(separator: "\n\n---\n\n")
    result += "\n"
    return result
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
      sandbox: read-only

      Explain this concept with one concrete example.
      ```
      """
  }

  private static func parseMetadata(from rawMarkdown: String) -> (theme: PresentationTheme, markdown: String) {
    var theme = PresentationTheme.studio
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
        theme = PresentationTheme(rawValue: value) ?? .studio
        lines.removeFirst()
      }
    }

    return (theme, lines.joined(separator: "\n"))
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
