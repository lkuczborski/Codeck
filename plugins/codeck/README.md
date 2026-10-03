# Codeck for Codex

A local macOS plugin that lets you create, edit, save, and present Markdown decks inside Codex. In Codex desktop, Codeck has its own sidebar workspace with a split editor and live preview, native file panels, fullscreen presentation, and the native Codex composer for iteration. Codex CLI can use its deck skills and MCP tools; the visual workspace requires the desktop app.

## Requirements

- Apple silicon Mac running macOS 14 or later for the prebuilt marketplace package. Intel Macs can build from source; Windows and Linux are not supported.
- A current Codex desktop app with support for workspace extensions, or a Codex CLI supporting `codex plugin` for tools and skills.
- An active Codex login and network access for live cards and Codex iteration. The plugin uses the installed Codex executable, including the copy bundled with the desktop app.
- For terminal installation, `codex` and Git must be available in your terminal, with network access to the public GitHub repository.

The Codeck Mac app does not need to be installed or running. Users do not need Swift, Node, npm, a separate OpenAI API key, or manual MCP server configuration. The package includes its native workspace helper, editor UI, icons, licenses, and skills. Release helpers are Developer ID signed and notarized by Apple; users do not perform signing or notarization.

## Install from the repository marketplace

These commands become usable after the first notarized plugin publication from `main`. Merging the source branch alone does not create the marketplace package.

### Codex CLI

```sh
codex plugin marketplace add lkuczborski/Codeck
codex plugin add codeck@codeck-plugins
```

Start a new CLI session to load the installed skills and tools. Ask Codex to create or edit a Codeck deck. The CLI plugin browser is available through `/plugins`.

### Codex desktop

Run the two commands above, restart Codex desktop, and open **Codeck** in the sidebar. With the default Codex profile on the same Mac, the CLI and desktop share the installed plugin. A different `CODEX_HOME` or profile can use a separate configuration.

To install through the desktop plugin browser, run only:

```sh
codex plugin marketplace add lkuczborski/Codeck
```

Restart Codex, open **Plugins**, choose **Codeck Plugins**, open **Codeck**, and install it. Start a new chat to use `@Codeck`, or open its sidebar workspace. This is a custom repository marketplace; publishing it does not automatically add Codeck to OpenAI's public Plugins Directory.

Codex downloads the prebuilt package from `codex/plugin-distribution` and installs a local copy. Users do not need to clone the source, download CI artifacts, or run a build script. See the [official marketplace guide](https://developers.openai.com/plugins/build/plugins#add-a-marketplace-from-the-cli) for supported sources and configuration.

## Update or uninstall

To install a newly published version:

```sh
codex plugin marketplace upgrade codeck-plugins
codex plugin add codeck@codeck-plugins
```

Then restart Codex desktop or start a new CLI session. This sequence explicitly refreshes the marketplace and installs its current package. Codex can also refresh configured plugins during marketplace refresh; the explicit install command ensures the selected package is installed. The app loads an installed copy, so editing source files does not refresh its displayed metadata or runtime.

Personal repository installs have no documented plugin-level setting that guarantees automatic update checks. Keep using the commands above unless your Codex host provides an automatic update option. Workspace-admin marketplace imports have a separate [daily sync mechanism](https://learn.chatgpt.com/docs/enterprise/plugin-management#keep-plugins-up-to-date); that schedule does not establish an automatic update guarantee for a personal CLI marketplace.

To uninstall:

```sh
codex plugin remove codeck@codeck-plugins
```

Deck files and persisted drafts remain in their storage folder outside the plugin package.

## Build and install locally

Run script commands from the repository root. Source builds require macOS 14+, a compatible Swift 6 toolchain, Node 20+, and npm. They produce an ad hoc signed development package for the build machine's architecture.

```sh
script/build_plugin.sh
codex plugin marketplace add ./dist
codex plugin add codeck@codeck-local
```

Restart Codex desktop or start a new CLI session. Rebuild and run `codex plugin add codeck@codeck-local` again after local source or metadata changes. Local builds use **Codeck Local** (`codeck-local`); published packages use **Codeck Plugins** (`codeck-plugins`).

The repository's `.agents/plugins/marketplace.json` points at the prebuilt package on `codex/plugin-distribution`. Generated executable and UI assets stay outside the source branch; source files and development dependencies live in `plugins/codeck/`. The plugin uses `.codex-plugin/plugin.json` and registers its MCP server as `codeck-workspace`.

## Troubleshooting

- **No Codeck marketplace:** run `codex plugin marketplace list`, confirm `codeck-plugins` is registered, and restart the desktop app. A published distribution branch must exist before the remote package can be installed.
- **No sidebar workspace:** confirm Codeck is installed and enabled, restart Codex, and check MCP startup errors for `codeck-workspace`. A loaded skill alone does not confirm that the native helper started. Hosts without the workspace extension can open the editor from a new chat by asking “Open the Codeck presentation workspace.”
- **Old name, metadata, or UI:** refresh the marketplace and run `plugin add` again, then restart Codex. For a local source build, rebuild the package first. Published source changes need a new plugin version and a release.
- **Live cards do not run:** check the installed Codex executable and login, network access, and whether the selected model is available to your account. Fence settings override deck settings; otherwise cards default to GPT-6.1 Sol with Light reasoning.

## Automatic packaging

The **Codeck plugin** GitHub Actions workflow runs for relevant source pushes and pull requests, and can also be run manually. Site-only edits do not trigger it. It builds on the Apple silicon `macos-15` runner with Xcode 26.3 selected explicitly, runs Swift and plugin tests plus TypeScript checks, verifies the native bundle, and uploads a `codeck-plugin-macos-arm64` artifact. Its inner `.tar.gz` preserves executable permissions and includes a local marketplace catalog. Extract it and add that extracted directory as a local marketplace to test a branch build. The accompanying SHA-256 file verifies the archive.

CI produces ad hoc signed development artifacts. Merging to `main` builds and tests a package; it does not publish it to users. Release signing credentials remain in the maintainer's Mac Keychain.

CI packages receive development versions such as `0.3.7-build.42` using the workflow run number. They are available for testing and are not marketplace releases.

## Release from your Mac

Publishing requires an Apple silicon Mac with the source-build tools, a Developer ID Application certificate and private key in Keychain, a working `notarytool` Keychain profile, and GitHub Git authentication with permission to push the distribution branch.

Merge before publishing: the release script rejects source that does not match remote `main`.

Bump `plugins/codeck/.codex-plugin/plugin.json`, `plugins/codeck/package.json`, and `plugins/codeck/package-lock.json` together for a new plugin version, commit the source, and merge to `main`. Update your local checkout to that merged commit. From the clean repository root, run:

```sh
export CODECK_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export CODECK_NOTARY_PROFILE="your-profile"
script/release_plugin.sh --publish
```

This builds and tests the plugin locally, signs its MCP executable and workspace helper with Developer ID and hardened runtime, submits them to Apple, staples the helper, and verifies the extracted ZIP with Gatekeeper. Publication requires the tested source to match the current remote `main`. Omit `--publish` to produce a notarized candidate from a feature branch. There is no need to download a CI build. The ZIP and checksum remain in `dist/plugin-release/<version>/`. The script publishes the marketplace branch; it does not create a GitHub release or upload ZIP assets. Those files can be attached to a GitHub release separately.

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

The plugin launcher defaults to `~/Documents/Codeck` and creates that presentation folder if needed. Open and Save use native macOS panels, which grant access to the selected file; ordinary use does not require editing configuration. Drafts stay outside the installed plugin package.

For a custom source build that needs additional roots for direct MCP file operations, set `CODECK_MCP_ALLOWED_ROOTS` to a colon-separated list of absolute folders to open/save elsewhere; the first folder becomes the working directory. Set `CODECK_MCP_WORKING_DIRECTORY` to choose a different working directory within those roots. Configure these in `plugins/codeck/.mcp.json` server `env`, rebuild, then install, for example:

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
