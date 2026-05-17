import Foundation

struct SlideTemplate: Identifiable, Hashable {
  let id: String
  let name: String
  let description: String
  let markdown: String
}

struct SlideTemplateSection: Identifiable, Hashable {
  let id: String
  let title: String
  let templates: [SlideTemplate]
}

enum SlideTemplateCatalog {
  static let sections: [SlideTemplateSection] = [
    SlideTemplateSection(
      id: "structure",
      title: "Structure",
      templates: [
        SlideTemplate(
          id: "title-thesis",
          name: "Title and Thesis",
          description: "Open a deck or section with a clear promise.",
          markdown:
            """
            # Working Title

            One sentence that says what this deck will make easier, clearer, or possible.
            """
        ),
        SlideTemplate(
          id: "agenda",
          name: "Agenda",
          description: "Set expectations with a simple ordered flow.",
          markdown:
            """
            # Agenda

            1. Context
            2. The key decision
            3. Demo or evidence
            4. Next steps
            """
        ),
        SlideTemplate(
          id: "section-break",
          name: "Section Break",
          description: "Mark a transition with one strong idea.",
          markdown:
            """
            # New Section

            > The shift in focus goes here.
            """
        )
      ]
    ),
    SlideTemplateSection(
      id: "analysis",
      title: "Analysis",
      templates: [
        SlideTemplate(
          id: "comparison",
          name: "Comparison",
          description: "Compare options, tradeoffs, or approaches.",
          markdown:
            """
            # Option Comparison

            | Option | Strength | Tradeoff |
            | --- | --- | --- |
            | A | Fast to ship | Leaves manual work |
            | B | More complete | Needs validation |
            """
        ),
        SlideTemplate(
          id: "status-update",
          name: "Status Update",
          description: "Summarize progress, risks, and ownership.",
          markdown:
            """
            # Status Update

            | Area | Status | Owner |
            | --- | --- | --- |
            | Shipped | Ready | Team |
            | Risk | Needs decision | Lead |
            | Next | In progress | Team |
            """
        ),
        SlideTemplate(
          id: "decision-brief",
          name: "Decision Brief",
          description: "Frame a recommendation and what changes next.",
          markdown:
            """
            # Decision Brief

            **Recommendation:** Choose the path that gives us the most learning this week.

            - Why now: the current constraint is clear
            - What changes: the team can move without another review loop
            - How we know: define one measurable signal
            """
        )
      ]
    ),
    SlideTemplateSection(
      id: "live-codex",
      title: "Live Codex",
      templates: [
        SlideTemplate(
          id: "codex-demo",
          name: "Codex Demo",
          description: "Run a focused live prompt during presentation.",
          markdown:
            """
            # Live Codex Demo

            ```codex id=demo-1
            title: Explain the implementation plan

            Review the current code and propose the smallest safe implementation plan.
            ```
            """
        ),
        SlideTemplate(
          id: "prompt-lab",
          name: "Prompt Lab",
          description: "Compare a rough prompt with a stronger one.",
          markdown:
            """
            # Prompt Lab

            | Draft | Improved |
            | --- | --- |
            | Make this better | Refactor this view into smaller SwiftUI subviews without changing behavior |

            ```codex id=prompt-review
            title: Improve this prompt

            Rewrite the draft prompt so it gives Codex clearer scope, constraints, and verification steps.
            ```
            """
        )
      ]
    )
  ]

  static var defaultTemplate: SlideTemplate? {
    sections.first?.templates.first
  }

  static func template(withID id: SlideTemplate.ID) -> SlideTemplate? {
    sections.lazy
      .flatMap(\.templates)
      .first { $0.id == id }
  }
}
