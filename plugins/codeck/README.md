# Codeck for Codex

A local macOS plugin with a dedicated presentation workspace. The UI registers a **global sidebar entry** and a **conversation panel entry** using the [OpenAI MCP Extensions API](https://developers.openai.com/plugins/build/extensions). Hosts that implement these extensions open Codeck as a permanent app tab with a composer. Older MCP Apps hosts can open the same editor from `open_workspace` in a chat.

## Install the prebuilt plugin

After the first locally notarized release from `main`, users on Apple silicon Macs can install from this repository without Swift, Node, npm, or the Codeck app:

```sh
codex plugin marketplace add lkuczborski/Codeck
codex plugin add codeck@codeck-plugins
```

Restart Codex and open **Codeck** in the sidebar. To update:

```sh
codex plugin marketplace upgrade codeck-plugins
codex plugin add codeck@codeck-plugins
```

Restart Codex after updating. Marketplace releases use Developer ID signing and Apple notarization. Intel Macs can use the source build until a compatible prebuilt release is available.

## Build and install locally

Requires macOS 14+, Swift 6, Node 20+, and npm. The Codeck app does not need to be running. The plugin bundles a native workspace helper, uses the installed Codex executable and login for live cards, and uses the native Codex composer for deck iteration. No OpenAI API key is needed.

From the repository root:

```sh
script/build_plugin.sh
codex plugin marketplace add ./dist
codex plugin add codeck@codeck-local
```

Restart Codex after installation or plugin updates, then open **Codeck** in the sidebar. If the host doesn't expose the sidebar extension yet, start a new chat and ask **“Open the Codeck presentation workspace.”** The permanent sidebar tab is host-controlled; this plugin doesn't modify Codex itself or add a fake sidebar link.

The plugin registers its MCP server as `codeck-workspace` so an existing `mcp_servers.codeck` connection for the native app cannot override it. If the sidebar entry is missing, check MCP startup errors for `codeck-workspace`; the plugin skill loading alone does not confirm that its server started.

The repo marketplace is `.agents/plugins/marketplace.json` and uses **Codeck Plugins** (`codeck-plugins`). It points at the tested package on the separate `codex/plugin-distribution` branch. Local builds create a separate `codeck-local` marketplace under `dist/`. The plugin uses the supported `.codex-plugin/plugin.json` compatibility format. Generated executable and UI assets are excluded from the source branch. `script/build_plugin.sh` packages only the Swift MCP executable, self-contained HTML, license notices, metadata, and skill; installed users don't need npm or Swift at runtime. Source files and development dependencies stay in `plugins/codeck/`. Rebuild and reinstall after local source changes.

## Automatic packaging

The **Codeck plugin** GitHub Actions workflow runs for relevant source pushes and pull requests, and can also be run manually. Site-only edits do not trigger it. It builds on the Apple silicon `macos-15` runner with Xcode 26.3 selected explicitly, runs Swift and plugin tests plus TypeScript checks, verifies the native bundle, and uploads a `codeck-plugin-macos-arm64` artifact. Its inner `.tar.gz` preserves executable permissions and includes a local marketplace catalog. Extract it and add that extracted directory as a local marketplace to test a branch build. The accompanying SHA-256 file verifies the archive.

CI produces ad hoc signed development artifacts. Merging to `main` builds and tests a package; it does not publish it to users. Release signing credentials remain in the maintainer's Mac Keychain.

CI packages receive development versions such as `0.3.7-build.42` using the workflow run number. They are available for testing and are not marketplace releases.

## Release from your Mac

Bump `.codex-plugin/plugin.json`, `package.json`, and `package-lock.json` together for a new plugin version, commit the source, and merge to `main`. From a clean checkout of that merged commit, run:

```sh
export CODECK_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export CODECK_NOTARY_PROFILE="your-profile"
script/release_plugin.sh --publish
```

This builds and tests the plugin locally, signs its MCP executable and workspace helper with Developer ID and hardened runtime, submits them to Apple, staples the helper, and verifies the extracted ZIP with Gatekeeper. Publication requires the tested source to match the current remote `main`. Omit `--publish` to produce a notarized candidate from a feature branch. There is no need to download a CI build. The ZIP and checksum remain in `dist/plugin-release/<version>/` and can also be attached to a GitHub release.

Publication updates `codex/plugin-distribution` with only the prebuilt plugin, marketplace catalog, `SOURCE_COMMIT`, and notarization receipt. It creates the branch on the first release, uses ordinary pushes, and rejects packages without a valid Developer ID signature and accepted notarization. Your existing GitHub authentication must allow pushing this branch. Source stays on `main`; no signing keys or Apple credentials are uploaded.

`script/notarize_plugin.sh <package-root> <tested-source-commit>` can also notarize an already built package. Users add the repository once and update through `codeck-plugins`; unpromoted CI builds never change their installed package.

## Editing

- **Library:** create a new presentation, open an existing `.mdeck`, `.md`, or `.markdown` file in the macOS Open panel, or resume a persisted draft.
- **Workspace:** slide thumbnails on the left, a highlighted CodeMirror editor and native-rendered live preview beside it. Drag the divider or use its arrow keys to resize. Toggle Markdown, split, and preview layouts. Drag thumbnails to reorder, or add, duplicate, and delete slides.
- **Formatting:** Insert headings, lists, quotes, links, images, code blocks, tables, dividers, and Codex cards. Bold, italic, inline code, strikethrough, and link buttons toggle formatting and reflect the caret’s active styles. ⌘B / ⌘I / ⌘K are available.
- **Highlighting:** GFM Markdown, YAML front matter, and language-aware fenced code, including Swift, Python, JavaScript/TypeScript, Rust, Go, Java/Kotlin, C/C++, C#, Ruby, PHP, shell, SQL, HTML, CSS, JSON, YAML, TOML, and other CodeMirror languages. Preview code uses the Mac app's exact Swift highlighter.
- **Iteration:** use the native Codex composer. The app supplies only the active workspace ID, revision, and file path as context. Selecting text, changing slides, and clicking the preview do not attach annotations or send prompts. The plugin has no separate annotation system or prompt panel.
- **Appearance:** interface colors and editor highlighting follow the host’s light/dark appearance and update when it changes. The presentation itself retains its chosen deck theme.
- **Save:** drafts persist automatically; **Save** / ⌘S writes a presentation file. **Save a copy** opens the macOS Save panel, which confirms existing destinations before replacement. External disk edits are never overwritten, even with overwrite enabled. Use Save As or explicitly reload/discard.
- **Present:** toolbar **Present** / ⌘Enter starts at the selected slide. Arrow keys, Space, Page Up/Down, Home, and End navigate; Esc exits. A native deck-only window fills the screen and hides the menu bar and Dock; the Codex sidebar and composer stay outside it. Split and preview-only layouts fit both the width and height of the slide.

The preview shares CodeckCore's parser, themes, Markdown renderer, and syntax highlighter with the native Mac app. PNG/JPEG/GIF/WebP assets within allowed roots are embedded (up to 5 MB per image). External image URLs are not fetched by this local plugin; use local assets. Live `codex` cards have Run and Stop controls in preview and fullscreen. They share the Mac app’s runner and respect fence overrides, then deck settings, then **GPT-6.1 Sol / Light** (`gpt-6.1-sol`, `low`). Results stream onto the slide without changing its Markdown. Results are session-only and reset when the plugin helper restarts.

## File access and persistence

The plugin launcher defaults to `~/Documents/Codeck` and creates that presentation folder if needed. Drafts stay outside the installed plugin package. Set `CODECK_MCP_ALLOWED_ROOTS` to a colon-separated list of absolute folders to open/save elsewhere; the first folder becomes the working directory. Set `CODECK_MCP_WORKING_DIRECTORY` to choose a different working directory within those roots. Configure these in `plugins/codeck/.mcp.json` server `env`, rebuild, then install, for example:

```json
"env": {
  "CODECK_MCP_ALLOWED_ROOTS": "/Users/you/Presentations:/Users/you/Projects"
}
```

Relative deck paths resolve against the presentation working directory. The library shows the configured roots. Selecting a file in the native Open or Save panel grants that exact canonical file persistently, without granting its parent directory. Canonical path checks include symlink destinations. The standalone `codeck-mcp` executable still defaults to its launch directory. The UI bundle comes from the trusted plugin package; file-reading tools remain scoped to the allowed roots.

Drafts and disk fingerprints live in `.codeck-workspaces/` under the first allowed root, with one JSON file per stable workspace UUID. Set `CODECK_WORKSPACE_STORAGE` to relocate this directory **within an allowed root**. Keep that directory to preserve drafts across reinstallations. Cross-process file locking and expected revisions protect concurrent editing. A clean workspace follows file MCP or disk changes; a dirty one preserves its draft and reports a disk conflict. If Codex changes the draft while editor changes are pending, the UI offers **Keep as new draft** or **Load latest**.

## Development and verification

```sh
swift build
swift test
script/format.sh
script/lint.sh
cd plugins/codeck
npm ci
npm run typecheck
npm run build
npm test
npm run preview
```

The loopback-only development host is `http://127.0.0.1:4179`. It runs the real Swift MCP server and records iteration messages without invoking a model. Add `?deck=Examples/SyntaxHighlighting.mdeck&theme=light` to open a specific deck and initial appearance. The development host has an appearance selector for testing live theme changes. Its HTTP bridge requires a per-process nonce and checks Origin/Host. Set `CODECK_PREVIEW_PORT` or `CODECK_MCP_EXECUTABLE` to change its port/executable.

Tests cover source ranges and fenced separators, prompt context, HTML packaging, MCP extension metadata, render parity, image access, persistence, revisions, legacy draft compatibility, disk conflicts, Save As collisions, and symlink escape checks. Actual sidebar placement and composer behavior should additionally be smoke-tested in the installed host after restart; the development host does not verify Codex's navigation UI.

## MCP tools

`open_workspace`, `read_workspace`, `update_workspace`, `save_workspace`, `reload_workspace`, `render_markdown` extend the existing file tools. Only `open_workspace` advertises the UI resource. Mutations update the existing editor rather than mounting replacement apps. Preview HTML stays in tool `_meta`; Markdown and revision stay model-visible. Polls supply `known_revision` to avoid transferring unchanged previews.
