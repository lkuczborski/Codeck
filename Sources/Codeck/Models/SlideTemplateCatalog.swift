import Foundation

enum SlideTemplateCatalog {
  static let sections: [SlideTemplateSection] = [
    SlideTemplateSection(
      id: "story",
      title: "Story and Framing",
      templates: [
        SlideTemplate(
          id: "opening-promise",
          name: "Opening Promise",
          description: "Start with the deck title and the value it promises.",
          markdown:
          """
          # Presentation Title

          A compact promise for what the audience will understand, decide, or be able to do by the end.
          """
        ),
        SlideTemplate(
          id: "problem-framing",
          name: "Problem Framing",
          description: "Name the tension before introducing the answer.",
          markdown:
          """
          # The Problem

          > The current workflow forces the team to spend attention in the wrong place.

          - Who feels it most
          - Where it appears in the work
          - Why it matters now
          """
        ),
        SlideTemplate(
          id: "big-number",
          name: "Big Number",
          description: "Anchor a section around one metric and its implication.",
          markdown:
          """
          # One Number to Remember

          ## 42%

          What changed, why it matters, and which decision this number should influence.
          """
        ),
        SlideTemplate(
          id: "customer-quote",
          name: "Customer Quote",
          description: "Use a direct voice or memorable observation as evidence.",
          markdown:
          """
          # Voice of the Customer

          > "The moment it clicked was when the work stopped feeling like setup and started feeling like progress."

          Segment, source, or interview context
          """
        ),
      ]
    ),
    SlideTemplateSection(
      id: "planning",
      title: "Planning and Decisions",
      templates: [
        SlideTemplate(
          id: "decision-matrix",
          name: "Decision Matrix",
          description: "Compare a few options against the criteria that matter.",
          markdown:
          """
          # Decision Matrix

          | Option | Best for | Risk | Recommendation |
          | --- | --- | --- | --- |
          | A | Fast learning | Manual follow-up | Short-term |
          | B | Durable workflow | More implementation | Preferred |
          """
        ),
        SlideTemplate(
          id: "roadmap",
          name: "Roadmap",
          description: "Show a sequence of phases without turning it into a table.",
          markdown:
          """
          # Roadmap

          1. **Now:** Validate the core workflow with real content.
          2. **Next:** Remove the largest source of manual cleanup.
          3. **Later:** Automate the repeatable path and measure adoption.
          """
        ),
        SlideTemplate(
          id: "risk-radar",
          name: "Risk Radar",
          description: "Separate risks, mitigations, and the ask.",
          markdown:
          """
          # Risk Radar

          **Primary risk:** The team optimizes the wrong part of the workflow.

          - Watch for: slow review cycles and repeated handoffs
          - Mitigate with: one owner and one validation checkpoint
          - Ask today: approve the next experiment
          """
        ),
        SlideTemplate(
          id: "before-after",
          name: "Before and After",
          description: "Make a process or product improvement easy to scan.",
          markdown:
          """
          # Before and After

          ## Before

          The old path, constraint, or user experience.

          ***

          ## After

          The improved path and the reason it matters.
          """
        ),
      ]
    ),
    SlideTemplateSection(
      id: "demo-teaching",
      title: "Demo and Teaching",
      templates: [
        SlideTemplate(
          id: "demo-runbook",
          name: "Demo Runbook",
          description: "Keep a live demo focused on the beats that matter.",
          markdown:
          """
          # Demo Runbook

          1. **Setup:** Start from the smallest believable example.
          2. **Show:** Perform the action the audience cares about.
          3. **Prove:** Check the result or compare before and after.
          4. **Fallback:** Know what to show if the live path fails.
          """
        ),
        SlideTemplate(
          id: "code-walkthrough",
          name: "Code Walkthrough",
          description: "Explain a small implementation detail with context.",
          markdown:
          """
          # Code Walkthrough

          The important part is how the boundary stays explicit.

          ```swift
          struct SlideStep {
            let goal: String
            let evidence: String
          }
          ```
          """
        ),
        SlideTemplate(
          id: "live-investigation",
          name: "Live Investigation",
          description: "Ask Codex to inspect, explain, or test something live.",
          markdown:
          """
          # Live Investigation

          ```codex id=investigate
          title: Inspect the current state

          Review the relevant files and explain what is happening, what is risky, and what should be verified next.
          ```
          """
        ),
        SlideTemplate(
          id: "workshop-exercise",
          name: "Workshop Exercise",
          description: "Give the audience a clear task and success criteria.",
          markdown:
          """
          # Workshop Exercise

          **Scenario:** A user needs to complete the workflow without reading documentation.

          - Define the first action they should take
          - Identify the feedback they need
          - Share one improvement you would make
          """
        ),
      ]
    ),
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
