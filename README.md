# Codeck

Codeck is a native macOS document-based Markdown presentation maker for teaching Codex prompting workflows.

## Document format

Documents use the `.mdeck` extension so macOS can associate them with Codeck
instead of the system Markdown editor. The body remains Markdown. Slides are
separated by a line containing only:

```markdown
---
```

Deck-level settings live in YAML front matter:

```markdown
---
format: codeck.mdeck
version: 1
theme: studio
codex:
  sandbox: read-only
  model: "gpt-5.2"
  reasoning: high
---

# First Slide
```

## Live Codex sessions

Add a fenced `codex` block to a slide:

````markdown
```codex id=refactor-demo
title: Explain the refactor goal
model: gpt-5.2
reasoning: xhigh
profile: teaching
sandbox: read-only

Explain how to refactor this SwiftUI view into smaller subviews.
```
````

Deck defaults for model, reasoning, profile, and sandbox are applied to every
Codex block. Any block can override those values with its own metadata.

Supported block metadata:

- `id`: stable session id used for output tracking and slide buttons. It can be
  written on the opening fence, as shown above, or as a metadata line.
- `title`: display title for the live Codex card. This should describe what the
  prompt is meant to demonstrate.
- `model`: per-block model override.
- `reasoning` or `reasoning_effort`: per-block reasoning override. Supported
  values are `low`, `medium`, `high`, and `xhigh`.
- `profile`: per-block Codex CLI profile override.
- `sandbox`: per-block sandbox override. Common values are `read-only`,
  `workspace-write`, and `danger-full-access`.

The prompt starts after the first blank line following the metadata.

Each live Codex card has its own run button on the slide. When a slide contains
multiple Codex sessions, a slide-level run-all button appears in the top-right
corner.

## Presenting

Press the toolbar play button to start a full-screen presentation from the
selected slide. Use the left and right arrow keys to navigate and Escape to exit.

## Local run loop

Use the project run script:

```bash
./script/build_and_run.sh
```

The Codex app Run button is wired to the same script through `.codex/environments/environment.toml`.
