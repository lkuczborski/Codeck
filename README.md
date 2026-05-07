# Codeck

![Codeck screenshot](screenshot.png)

Codeck is a native macOS document-based Markdown presentation maker for teaching Codex prompting workflows.

## Examples

The [`Examples`](Examples) folder contains sample `.mdeck` decks:

- [`CodeckFeatureCarnival.mdeck`](Examples/CodeckFeatureCarnival.mdeck) is a
  short, playful tour of Codeck's core workflow: Markdown slides, themes, live
  preview, presentation mode, web images and GIFs, and runnable Codex cards.
- [`SyntaxHighlighting.mdeck`](Examples/SyntaxHighlighting.mdeck) shows fenced
  code highlighting across the supported language labels and aliases.

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
  model: "gpt-5.5"
  reasoning: medium
---

# First Slide
```

Supported deck metadata:

- `format`: should be `codeck.mdeck`.
- `version`: current document version is `1`.
- `theme`: presentation theme. Supported values are `studio`, `midnight`,
  `chalk`, `solar`, and `atelier`.
- `codex.sandbox`: default sandbox for live Codex sessions. Defaults to
  `read-only`.
- `codex.model`: default model for live Codex sessions. Codeck fetches the
  available model list from `codex app-server` and falls back to `gpt-5.5` if
  Codex is unavailable.
- `codex.reasoning` or `codex.reasoning_effort`: default reasoning effort.
  Codeck fetches the supported values for the selected model from Codex and
  falls back to `low`, `medium`, `high`, and `xhigh`. Defaults to `medium`.

## Live Codex sessions

Add a fenced `codex` block to a slide:

````markdown
```codex id=refactor-demo
title: Explain the refactor goal
model: gpt-5.5
reasoning: xhigh
sandbox: read-only

Explain how to refactor this SwiftUI view into smaller subviews.
```
````

Deck defaults for model, reasoning, and sandbox are applied to every Codex
block. Any block can override those values with its own metadata.
Live sessions run through `codex app-server --listen stdio://`, so Codeck needs
the Codex CLI available on `PATH` and an active Codex login.

Supported block metadata:

- `id`: stable session id used for output tracking and slide buttons. It can be
  written on the opening fence, as shown above, or as a metadata line.
- `title`: display title for the live Codex card. This should describe what the
  prompt is meant to demonstrate.
- `model`: per-block model override.
- `reasoning` or `reasoning_effort`: per-block reasoning override. Supported
  values come from the selected Codex model.
- `sandbox`: per-block sandbox override. Common values are `read-only`,
  `workspace-write`, and `danger-full-access`.

Codeck always shows the Markdown response from Codex. While a session is running
and before the first response token arrives, the output area shows `Thinking...`.

The prompt starts after the first blank line following the metadata.

Each live Codex card has its own run button on the slide. When a slide contains
multiple Codex sessions, a slide-level run-all button appears in the top-right
corner. Codex responses stream into the slide live and are rendered as Markdown,
so lists, headings, tables, code, links, and images in the response use the same
renderer as the rest of the deck.

Fenced code blocks support syntax highlighting when the opening fence includes a
language, such as ```` ```swift ```` or ```` ```json ````.

## MCP server

Codeck includes a file-based MCP server so other agents can create and edit
`.mdeck` decks without driving the macOS UI. Build or run the `codeck-mcp`
executable from the repository root:

```bash
swift run codeck-mcp
```

By default, the server can read and write only inside its current working
directory. Set `CODECK_MCP_ALLOWED_ROOTS` to a colon-separated list when an MCP
client should work elsewhere:

```bash
CODECK_MCP_ALLOWED_ROOTS="$HOME/Documents:/tmp" swift run codeck-mcp
```

The server speaks MCP over stdio and exposes tools for deck and slide mutation:

- `create_deck`
- `read_deck`
- `list_slides`
- `get_slide`
- `set_slide_markdown`
- `insert_slide`
- `delete_slide`
- `move_slide`
- `duplicate_slide`
- `set_deck_settings`
- `insert_codex_block`
- `validate_deck`

It also exposes a resource template for read-only deck context:

```text
codeck://file/deck{?path,view,index}
```

Use `view=document` for the full Markdown document, `view=outline` for a JSON
outline, or `view=slide&index=0` for a specific slide. Slide indexes are
zero-based; slide UUIDs are runtime-only and are not persisted in `.mdeck`
files.

## Live MCP bridge

Codeck can also expose the currently open app windows through a localhost MCP
bridge. This is disabled by default.

To enable it in the app:

1. Open Codeck settings.
2. Enable **MCP > Live Bridge**.
3. Keep Codeck running with the deck window open.

When enabled, Codeck listens on:

```text
http://127.0.0.1:49747/mcp
```

The live bridge uses MCP Streamable HTTP with JSON responses. Configure an
agent or MCP client with a Streamable HTTP server named `codeck` pointing
to that URL. For clients that use the common JSON MCP manifest shape, the entry
looks like:

```json
{
  "mcpServers": {
    "codeck": {
      "transport": "streamable-http",
      "url": "http://127.0.0.1:49747/mcp"
    }
  }
}
```

Some clients use `type: "http"` or `type: "streamable-http"` instead of
`transport`; use the field name expected by that agent, but keep the same URL.
After adding the server to the agent, ask it to call `list_open_decks` first so
it can get the live `document_id` for the Codeck window it should edit.

Live bridge tools:

- `list_open_decks`
- `read_deck`
- `list_slides`
- `get_slide`
- `set_slide_markdown`
- `insert_slide`
- `delete_slide`
- `move_slide`
- `duplicate_slide`
- `set_deck_settings`
- `insert_codex_block`
- `select_slide`
- `get_selection`
- `start_presentation`
- `stop_presentation`
- `validate_deck`

Live bridge resources use:

```text
codeck://live/deck/{document_id}{?view,index}
```

Use `view=document` for full Markdown, `view=outline` for a JSON outline, or
`view=slide&index=0` for a specific slide. The shared `codeck://` scheme uses
`file` and `live` host segments so agents can distinguish file-backed deck
resources from open app-window resources.

## Presenting

Press the toolbar play button to start a full-screen presentation from the
selected slide. Use the left and right arrow keys to navigate and Escape to exit.

## Local run loop

Use the project run script:

```bash
./script/build_and_run.sh
```

The Codex app Run button is wired to the same script through `.codex/environments/environment.toml`.
