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
reasoning: xhigh

Explain how to refactor this SwiftUI view into smaller subviews.
```
````

Deck defaults for model, reasoning, profile, and sandbox are applied to every
Codex block. Any block can override those values with its own metadata.

The preview pane can run one or all Codex blocks on the selected slide and streams the command output into the rendered presentation preview.

## Local run loop

Use the project run script:

```bash
./script/build_and_run.sh
```

The Codex app Run button is wired to the same script through `.codex/environments/environment.toml`.
