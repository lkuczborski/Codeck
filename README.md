# Codeck

Codeck is a native macOS document-based Markdown presentation maker for teaching Codex prompting workflows.

## Document format

Documents are Markdown files. Slides are separated by a line containing only:

```markdown
---
```

The selected presentation theme is saved in a top-level HTML comment:

```markdown
<!-- codeck-theme: studio -->
```

## Live Codex sessions

Add a fenced `codex` block to a slide:

````markdown
```codex id=refactor-demo
sandbox: read-only
model: gpt-5.2

Explain how to refactor this SwiftUI view into smaller subviews.
```
````

The preview pane can run one or all Codex blocks on the selected slide and streams the command output into the rendered presentation preview.

## Local run loop

Use the project run script:

```bash
./script/build_and_run.sh
```

The Codex app Run button is wired to the same script through `.codex/environments/environment.toml`.
