# Codeck

**A native macOS Markdown deck editor for presentations that need live AI work, not just static slides.**

![Codeck showing a Markdown editor, rendered slide preview, and Deck Assistant proposals](screenshot.png)

Codeck helps you build presentations as readable Markdown, preview them as polished slides, run Codex prompts directly inside a deck, and use the Deck Assistant to turn rough content into proposed Markdown edits. It is designed for people who teach, demo, brief, or workshop AI workflows and want the source of the deck to stay simple, inspectable, and easy to version.

## Why Codeck

Most presentation tools separate the script, the source material, the live demo, and the AI assistant into different windows. Codeck brings those pieces into one native Mac loop:

- **Write in Markdown:** Decks are plain-text `.mdeck` files with YAML front matter and `---` slide separators.
- **Preview as you work:** The editor, slide list, and rendered presentation view stay together.
- **Run Codex from a slide:** Fenced `codex` blocks become live prompt cards with model, reasoning, and sandbox settings.
- **Improve a deck with Codex:** The Deck Assistant can review one slide or the whole deck and return selectable insertions and replacements.
- **Present without exporting:** Start full-screen presentation mode from the selected slide.
- **Let agents edit decks:** Use the file-based MCP server or live app bridge to create, inspect, and mutate decks programmatically.

## What You Can Build

- **AI training decks:** Teach prompting, evaluation, code review, or agent workflows with runnable examples on the slide.
- **Live demo talks:** Keep the prompt, context, expected behavior, and streamed Codex response in the same artifact.
- **Executive briefings:** Draft a rough narrative, ask the Deck Assistant to sharpen it, add evidence, and apply only the changes you trust.
- **Research and product narratives:** Use Markdown, tables, links, images, citations, and web-backed assistant passes to keep claims grounded.
- **Workshops and exercises:** Build decks where each slide can ask Codex to inspect, explain, test, or transform something live.
- **Agent-editable documentation:** Give another MCP-capable agent a `.mdeck` file or an open Codeck window and let it insert slides, update settings, or validate the deck.

## Core Features

- Native macOS document app for `.mdeck` files.
- Markdown slides with headings, lists, blockquotes, tables, links, images, GIFs, and fenced code blocks.
- Syntax highlighting for common code fence languages.
- Theme picker with Studio, Midnight, Chalk, Solar, and Atelier presentation themes.
- Sidebar for scanning, selecting, adding, duplicating, deleting, and organizing slides.
- Live preview beside the editor, plus compact modes for smaller windows.
- Insert tools for common Markdown blocks, images, tables, and Codex cards.
- Deck-level Codex defaults for model, reasoning effort, and sandbox.
- Per-slide live Codex cards, per-card overrides, streaming Markdown output, and run-all on slides with multiple sessions.
- Deck Assistant with Slide and Deck scopes, quick actions for Find Gaps, Shorten, Polish, Research, and Add Data, optional web use, selectable changes, and one-click apply.
- Full-screen presentation mode with keyboard navigation.
- File-based MCP server for deck automation outside the app.
- Live localhost MCP bridge for agents that need to work with currently open Codeck windows.

## Quick Start

Codeck is a Swift Package Manager project for macOS 14+.

Install local tools:

```bash
brew bundle
```

Build the package:

```bash
swift build
```

Build and launch the app bundle:

```bash
./script/build_and_run.sh
```

Run the tests:

```bash
swift test
```

Live Codex features need the Codex CLI available on `PATH` and an active Codex login. Codeck runs live sessions through `codex app-server --listen stdio://`.

## Examples

The [`Examples`](Examples) folder contains sample `.mdeck` decks:

- [`CodeckFeatureCarnival.mdeck`](Examples/CodeckFeatureCarnival.mdeck) is a short tour of Codeck's core workflow: Markdown slides, themes, live preview, presentation mode, web images and GIFs, and runnable Codex cards.
- [`SyntaxHighlighting.mdeck`](Examples/SyntaxHighlighting.mdeck) shows fenced code highlighting across supported language labels and aliases.

## Document Format

Documents use the `.mdeck` extension so macOS can associate them with Codeck instead of the system Markdown editor. The body remains Markdown. Slides are separated by a line containing only:

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
- `theme`: presentation theme. Supported values are `studio`, `midnight`, `chalk`, `solar`, and `atelier`.
- `codex.sandbox`: default sandbox for live Codex sessions. Defaults to `read-only`.
- `codex.model`: default model for live Codex sessions. Codeck fetches the available model list from `codex app-server` and falls back to `gpt-5.5` if Codex is unavailable.
- `codex.reasoning` or `codex.reasoning_effort`: default reasoning effort. Codeck fetches the supported values for the selected model from Codex and falls back to `low`, `medium`, `high`, and `xhigh`. Defaults to `medium`.

## Live Codex Sessions

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

Deck defaults for model, reasoning, and sandbox are applied to every Codex block. Any block can override those values with its own metadata.

Supported block metadata:

- `id`: stable session id used for output tracking and slide buttons. It can be written on the opening fence, as shown above, or as a metadata line.
- `title`: display title for the live Codex card. This should describe what the prompt is meant to demonstrate.
- `model`: per-block model override.
- `reasoning` or `reasoning_effort`: per-block reasoning override. Supported values come from the selected Codex model.
- `sandbox`: per-block sandbox override. Common values are `read-only`, `workspace-write`, and `danger-full-access`.

The prompt starts after the first blank line following the metadata. Codeck always shows the Markdown response from Codex. While a session is running and before the first response token arrives, the output area shows `Thinking...`.

Each live Codex card has its own run button on the slide. When a slide contains multiple Codex sessions, a slide-level run-all button appears in the top-right corner. Codex responses stream into the slide live and are rendered as Markdown, so lists, headings, tables, code, links, and images in the response use the same renderer as the rest of the deck.

Fenced code blocks support syntax highlighting when the opening fence includes a language, such as ```` ```swift ```` or ```` ```json ````.

## Deck Assistant

The Deck Assistant is built for editing the presentation itself, not just chatting about it. It can work on the selected slide or the whole deck, then return concrete change proposals that you can review before applying.

Useful assistant passes include:

- **Find Gaps:** Identify missing, unclear, unsupported, or weak parts of the deck.
- **Shorten:** Reduce filler and make slides easier to present.
- **Polish:** Make the deck more professional, precise, and executive-ready.
- **Research:** Add current context and cite trustworthy sources when external facts are used.
- **Add Data:** Strengthen an argument with useful data, benchmarks, comparisons, or evidence.

The assistant can optionally use web research for passes where current facts or citations matter. Proposed changes remain selectable, so you can apply the edits that fit and ignore the rest.

## MCP Server

Codeck includes a file-based MCP server so other agents can create and edit `.mdeck` decks without driving the macOS UI. Build or run the `codeck-mcp` executable from the repository root:

```bash
swift run codeck-mcp
```

By default, the server can read and write only inside its current working directory. Set `CODECK_MCP_ALLOWED_ROOTS` to a colon-separated list when an MCP client should work elsewhere:

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

Use `view=document` for the full Markdown document, `view=outline` for a JSON outline, or `view=slide&index=0` for a specific slide. Slide indexes are zero-based; slide UUIDs are runtime-only and are not persisted in `.mdeck` files.

## Live MCP Bridge

Codeck can also expose the currently open app windows through a localhost MCP bridge. This is disabled by default.

To enable it in the app:

1. Open Codeck settings.
2. Enable **MCP > Live Bridge**.
3. Keep Codeck running with the deck window open.

When enabled, Codeck listens on:

```text
http://127.0.0.1:49747/mcp
```

The live bridge uses MCP Streamable HTTP with JSON responses. Configure an agent or MCP client with a Streamable HTTP server named `codeck` pointing to that URL. For clients that use the common JSON MCP manifest shape, the entry looks like:

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

Some clients use `type: "http"` or `type: "streamable-http"` instead of `transport`; use the field name expected by that agent, but keep the same URL. After adding the server to the agent, ask it to call `list_open_decks` first so it can get the live `document_id` for the Codeck window it should edit.

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

Use `view=document` for full Markdown, `view=outline` for a JSON outline, or `view=slide&index=0` for a specific slide. The shared `codeck://` scheme uses `file` and `live` host segments so agents can distinguish file-backed deck resources from open app-window resources.

## Presenting

Press the toolbar play button to start a full-screen presentation from the selected slide. Use the left and right arrow keys to navigate and Escape to exit.

## Development

Useful checks:

```bash
swift test
script/format.sh
script/lint.sh
```

The Codex app Run button is wired to `./script/build_and_run.sh` through `.codex/environments/environment.toml`.
