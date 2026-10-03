import CodeckCore
import CoreFoundation
import Foundation

/// Calls arrive serially on the MCP worker. Presentation callbacks only render
/// immutable deck snapshots; run state is independently protected by its lock.
final class CodeckWorkspaceTools: @unchecked Sendable {
    static let resourceURI = "ui://codeck/workspace/v3.html"
    private let paths: PathAccessGuard
    private let store: CodeckWorkspaceStore
    private let runs = CodeckCardRuns()

    init(paths: PathAccessGuard) {
        self.paths = paths
        let directory = ProcessInfo.processInfo.environment["CODECK_WORKSPACE_STORAGE"].map { URL(fileURLWithPath: $0) }
            ?? paths.allowedRoots[0].appendingPathComponent(".codeck-workspaces")
        store = CodeckWorkspaceStore(directory: directory, resolve: paths.resolve)
    }

    var tools: [[String: Any]] {
        let identity: [String: Any] = [
            "workspace_id": stringSchema("Persistent workspace UUID from open_workspace. Reuse it throughout iteration."),
            "revision": integerSchema("Latest revision from read_workspace. Required for all mutations."),
        ]
        var open = tool(
            "open_workspace",
            "Open Codeck's presentation workspace. Empty arguments open the library; path opens a disk deck; markdown creates a persistent draft.",
            behavior: .localChange,
            properties: [
                "path": stringSchema("Existing deck path within allowed roots."),
                "markdown": stringSchema("Initial full Markdown for a new draft."),
                "title": stringSchema("New draft title."),
                "workspace_id": identity["workspace_id"]!,
            ]
        )
        open["title"] = "Codeck"
        let icon = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="none"
          stroke="currentColor" stroke-width="1.33" stroke-linecap="round" stroke-linejoin="round">
          <path d="M15 5V4a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h1"/>
          <rect x="5" y="5" width="13" height="13" rx="2"/>
          <path d="m10 9-2 2.5 2 2.5m3-5 2 2.5-2 2.5"/>
        </svg>
        """
        open["icons"] = [["src": "data:image/svg+xml;base64," + Data(icon.utf8).base64EncodedString(), "mimeType": "image/svg+xml"]]
        open["_meta"] = [
            "ui": ["resourceUri": Self.resourceURI, "visibility": ["model", "app"]],
            "openai/ui": ["entrypoints": [["type": "global"], ["type": "thread"]]],
            "openai/outputTemplate": Self.resourceURI,
            "openai/widgetAccessible": true,
        ]
        var result = [
            open,
            tool(
                "read_workspace",
                "Read the latest draft. Refreshes clean decks changed on disk. Call before iteration; use the returned revision.",
                behavior: .localChange,
                properties: [
                    "workspace_id": identity["workspace_id"]!,
                    "known_revision": integerSchema("Optional polling revision; unchanged results are small receipts."),
                ],
                required: ["workspace_id"]
            ),
            tool("update_workspace", "Replace the full Markdown draft at the expected revision. Updates the already-open editor; does not save to disk.",
                 behavior: .localReplace,
                 properties: identity.merging(["markdown": stringSchema("Full replacement Markdown including front matter.")]) { _, new in new },
                 required: ["workspace_id", "revision", "markdown"]),
            tool("save_workspace", "Save a draft to disk. Refuses external changes and existing Save As destinations unless overwrite is explicit.",
                 behavior: .localReplace,
                 properties: identity.merging([
                     "path": stringSchema("Save As path; omit to save the current disk file."),
                     "overwrite": booleanSchema("Explicitly permit replacing an existing Save As destination."),
                 ]) { _, new in new }, required: ["workspace_id", "revision"]),
            tool("reload_workspace", "Discard the local draft and reload its disk file. Use only when the user asks to discard changes.",
                 behavior: .localReplace,
                 properties: identity, required: ["workspace_id", "revision"]),
            tool("render_markdown", "Preview unsaved Markdown using the Mac app's parser, themes, and code highlighter. No files are changed.",
                 behavior: .readOnly,
                 properties: [
                     "markdown": stringSchema("Full deck Markdown."),
                     "path": stringSchema("Optional deck path for local media resolution."),
                     "workspace_id": identity["workspace_id"]!,
                 ],
                 required: ["markdown"]),
        ]
        for index in result.indices {
            if index > 0 { result[index]["_meta"] = ["ui": ["visibility": ["model", "app"]], "openai/widgetAccessible": true] }
        }
        let appTools = [
            tool("choose_open_workspace", "Show the macOS Open panel. Only the user's selected deck receives file access.",
                 behavior: .localChange, properties: [:]),
            tool(
                "choose_save_workspace",
                "Show the macOS Save panel and save the user's selected file.",
                behavior: .localReplace,
                properties: identity,
                required: ["workspace_id", "revision"]
            ),
            tool("present_workspace", "Present only the deck in a native computer fullscreen window. Escape exits.",
                 behavior: .localChange,
                 properties: identity.merging(["slide_index": integerSchema("Starting slide index.")]) { _, new in new }, required: [
                     "workspace_id",
                     "revision",
                     "slide_index",
                 ]),
            tool("begin_codex_run", "Run a user-initiated card with the deck and fence model, reasoning, and sandbox settings.",
                 behavior: .codexExecution,
                 properties: identity.merging([
                     "slide_index": integerSchema("Card's slide index."),
                     "block_id": stringSchema("Validated Codex card id."),
                 ]) { _, new in new },
                 required: ["workspace_id", "revision", "slide_index", "block_id"]),
            tool("poll_codex_runs", "Poll card results without changing the deck's Markdown or revision.",
                 behavior: .localChange,
                 properties: ["workspace_id": identity["workspace_id"]!, "known_version": integerSchema("Last run version.")], required: ["workspace_id"]),
            tool("stop_codex_run", "Cancel a running Codex card process and stop accepting its output.",
                 behavior: .localReplace,
                 properties: ["run_id": stringSchema("Run UUID.")], required: ["run_id"]),
        ]
        for var item in appTools {
            item["_meta"] = ["ui": ["visibility": ["app"]], "openai/widgetAccessible": true]
            result.append(item)
        }
        return result
    }

    func handles(_ name: String) -> Bool {
        tools.contains { $0["name"] as? String == name }
    }

    private func appCall(_ name: String, arguments: [String: Any]) throws -> [String: Any]? {
        switch name {
        case "choose_open_workspace":
            guard let url = desktop({ WorkspaceDesktop.shared.chooseOpen() }) else { return receipt(["cancelled": true]) }
            return try response(store.open(path: paths.grantPickedFile(url).path), opened: true)
        case "choose_save_workspace":
            let state = try checked(arguments)
            guard let url = desktop({ WorkspaceDesktop.shared.chooseSave(path: state.path, title: state.title) }) else { return receipt(["cancelled": true]) }
            let path = try paths.grantPickedFile(url).path
            return try response(store.save(state.id, revision: state.revision, path: path, overwrite: true))
        case "present_workspace":
            return try present(arguments)
        case "begin_codex_run":
            let state = try checked(arguments)
            guard let index = try integer(arguments, "slide_index") else { throw CodeckMCPError.invalidParams("Missing slide index.") }
            let run = try runs.begin(workspace: state, slideIndex: index, blockID: requiredString(arguments, "block_id"))
            desktop { WorkspaceDesktop.shared.startConfiguredRun(run, runs: runs, directory: paths.allowedRoots[0]) }
            return try receipt(["run": object(run)])
        case "poll_codex_runs":
            let id = try requiredString(arguments, "workspace_id")
            let state = try store.read(id)
            let snapshot = runs.snapshot(id)
            if try integer(arguments, "known_version") == snapshot.version { return receipt(["version": snapshot.version, "unchanged": true]) }
            var result = try receipt(["version": snapshot.version, "runs": snapshot.runs.map(object)])
            result["_meta"] = try ["preview": preview(state.markdown, path: state.path, workspaceID: id)]
            return result
        case "stop_codex_run":
            let id = try requiredString(arguments, "run_id")
            runs.stop(id)
            desktop { WorkspaceDesktop.shared.stopRun(id) }
            return receipt(["stopped": true])
        default: return nil
        }
    }

    func call(_ name: String, arguments: [String: Any]) throws -> [String: Any] {
        if let result = try appCall(name, arguments: arguments) { return result }
        if name == "render_markdown" {
            guard let markdown = arguments["markdown"] as? String, markdown.utf8.count <= 2_000_000 else {
                throw CodeckMCPError.invalidParams("Provide Markdown of at most 2 MB.")
            }
            return try [
                "content": [["type": "text", "text": "Deck preview rendered."]],
                "_meta": ["preview": preview(markdown, path: optionalString(arguments, "path"), workspaceID: optionalString(arguments, "workspace_id"))],
            ]
        }
        if name == "open_workspace", arguments.isEmpty {
            let recent = try store.list().prefix(30).map { state -> [String: Any] in
                ["id": state.id, "title": state.title, "path": state.path as Any? ?? NSNull(), "dirty": state.dirty]
            }
            return [
                "content": [["type": "text", "text": "Codeck workspace opened. Choose a deck or create a new presentation."]],
                "structuredContent": ["recent": recent, "allowedRoots": paths.allowedRoots.map(\.path)],
                "_meta": ["openai/outputTemplate": Self.resourceURI],
            ]
        }
        let state: DeckWorkspace
        if name == "open_workspace" {
            if let id = optionalString(arguments, "workspace_id") {
                state = try store.read(id)
            } else {
                state = try store.open(path: optionalString(arguments, "path"), markdown: arguments["markdown"] as? String,
                                       title: optionalString(arguments, "title") ?? "Untitled deck")
            }
        } else {
            let id = try requiredString(arguments, "workspace_id")
            if name == "read_workspace" {
                state = try store.read(id)
            } else {
                guard let revision = try integer(arguments, "revision") else { throw CodeckMCPError.invalidParams("Missing revision.") }
                switch name {
                case "update_workspace":
                    guard let markdown = arguments["markdown"] as? String else { throw CodeckMCPError.invalidParams("Missing markdown.") }
                    state = try store.update(id, revision: revision, markdown: markdown)
                case "save_workspace":
                    state = try store.save(id, revision: revision, path: optionalString(arguments, "path"),
                                           overwrite: optionalBool(arguments, "overwrite") ?? false)
                case "reload_workspace":
                    state = try store.reload(id, revision: revision)
                default: throw CodeckMCPError.invalidParams("Unknown workspace tool.")
                }
            }
        }
        if name == "read_workspace", try integer(arguments, "known_revision") == state.revision {
            return ["structuredContent": ["id": state.id, "revision": state.revision, "unchanged": true,
                                          "diskAccessRequired": diskAccessRequired(state)], "content": []]
        }
        return try response(state, opened: name == "open_workspace")
    }

    private func present(_ arguments: [String: Any]) throws -> [String: Any] {
        let state = try checked(arguments)
        let deck = PresentationDeck(markdownDocument: state.markdown)
        let initial = try integer(arguments, "slide_index") ?? 0
        guard deck.slides.indices.contains(initial) else { throw CodeckMCPError.invalidParams("Invalid slide index.") }
        try desktop {
            try WorkspaceDesktop.shared.present(count: deck.slides.count, initialIndex: initial, render: { index in
                let rendered = try self.preview(state.markdown, path: state.path, workspaceID: state.id)
                guard let slides = rendered["slides"] as? [[String: Any]], slides.indices.contains(index),
                      let html = slides[index]["html"] as? String
                else {
                    throw CodeckMCPError.operationFailed("Could not render the presentation slide.")
                }
                return html
            }, version: { self.runs.snapshot(state.id).version }, cardAction: { index, id, stop in
                if stop {
                    if let run = self.runs.snapshot(state.id).runs.last(where: { $0.blockID == id }) { self.runs.stop(run.id)
                        WorkspaceDesktop.shared.stopRun(run.id)
                    }
                } else {
                    let run = try self.runs.begin(workspace: state, slideIndex: index, blockID: id)
                    WorkspaceDesktop.shared.startConfiguredRun(run, runs: self.runs, directory: self.paths.allowedRoots[0])
                }
            })
        }
        return receipt(["presenting": true])
    }

    private func response(_ state: DeckWorkspace, opened: Bool = false) throws -> [String: Any] {
        let data = try JSONEncoder().encode(state)
        guard var payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodeckMCPError.operationFailed("Could not encode workspace state.")
        }
        payload["dirty"] = state.dirty
        payload["diskAccessRequired"] = diskAccessRequired(state)
        let deck = PresentationDeck(markdownDocument: state.markdown)
        payload["slides"] = deck.slides.enumerated().map { index, slide in ["index": index, "title": slide.title, "markdown": slide.markdown] as [String: Any] }
        payload["theme"] = deck.theme.rawValue
        var metadata: [String: Any] = try ["preview": preview(state.markdown, path: state.path, workspaceID: state.id), "openai/widgetSessionId": state.id]
        if opened { metadata["openai/outputTemplate"] = Self.resourceURI }
        return ["structuredContent": payload, "content": [["type": "text", "text": String(decoding: data, as: UTF8.self)]], "_meta": metadata]
    }

    private func checked(_ arguments: [String: Any]) throws -> DeckWorkspace {
        let state = try store.read(requiredString(arguments, "workspace_id"))
        guard try integer(arguments, "revision") == state.revision else { throw CodeckWorkspaceError.conflict }
        return state
    }

    private func receipt(_ data: [String: Any]) -> [String: Any] {
        ["structuredContent": data, "content": []]
    }

    private func diskAccessRequired(_ state: DeckWorkspace) -> Bool {
        guard let path = state.path else { return false }
        return (try? paths.resolve(path)) == nil
    }

    private func object(_ run: CodeckCardRun) throws -> [String: Any] {
        guard let result = try JSONSerialization.jsonObject(with: JSONEncoder().encode(run)) as? [String: Any] else {
            throw CodeckMCPError.operationFailed("Could not encode card state.")
        }
        return result
    }

    private func desktop<T: Sendable>(_ operation: @MainActor () throws -> T) rethrows -> T {
        try DispatchQueue.main.sync { try MainActor.assumeIsolated { try operation() } }
    }

    private func number(_ arguments: [String: Any], _ key: String) throws -> Double? {
        guard let value = arguments[key] else { return nil }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else {
            throw CodeckMCPError.invalidParams("Argument '\(key)' must be a finite number.")
        }
        return number.doubleValue
    }

    private func integer(_ arguments: [String: Any], _ key: String) throws -> Int? {
        guard let value = try number(arguments, key) else { return nil }
        guard let result = Int(exactly: value) else { throw CodeckMCPError.invalidParams("Argument '\(key)' must be an integer.") }
        return result
    }

    func resource() throws -> [String: Any] {
        let env = ProcessInfo.processInfo.environment["CODECK_WORKSPACE_UI_PATH"]
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let candidates = [env.map { URL(fileURLWithPath: $0) }, executable.deletingLastPathComponent().appendingPathComponent("workspace.html"),
                          URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("plugins/codeck/build/workspace.html")]
            .compactMap(\.self)
        guard let file = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CodeckMCPError.operationFailed("Build the Codeck plugin UI with script/build_plugin.sh first.")
        }
        return try ["uri": Self.resourceURI, "mimeType": "text/html;profile=mcp-app", "text": String(contentsOf: file, encoding: .utf8),
                    "_meta": ["ui": ["prefersBorder": false, "csp": ["resourceDomains": ["data:", "blob:"], "connectDomains": []]],
                              "openai/ui": ["preferredDisplayMode": "fullscreen", "availableDisplayModes": ["inline", "fullscreen"]]]]
    }

    private func preview(_ markdown: String, path: String?, workspaceID: String? = nil) throws -> [String: Any] {
        let deck = PresentationDeck(markdownDocument: markdown)
        // Render the stored Markdown even when disk access needs renewed approval.
        // Local images are only read after their own path authorization below.
        let directory = path.flatMap { try? paths.resolve($0).deletingLastPathComponent() }
        let slides = try deck.slides.enumerated().map { index, slide -> [String: Any] in
            let outputs = workspaceID.map { runs.outputs($0, blocks: slide.codexBlocks, settings: deck.settings.codex) } ?? [:]
            var html = MarkdownRenderer.htmlDocument(for: slide, theme: deck.theme, codexOutputs: outputs)
            // Local images are embedded so the isolated MCP App never needs filesystem or network access.
            let expression = try NSRegularExpression(pattern: #"<img src="([^"]+)""#)
            for match in expression.matches(in: html, range: NSRange(html.startIndex..., in: html)).reversed() {
                guard let range = Range(match.range(at: 1), in: html) else { continue }
                let source = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
                guard let directory, !source.contains("://"), !source.hasPrefix("data:"), !source.hasPrefix("//") else { continue }
                let rawPath = source.hasPrefix("/") ? source : directory.appendingPathComponent(source.removingPercentEncoding ?? source).path
                guard let imageURL = try? paths.resolve(rawPath) else { continue }
                let types = ["png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp"]
                guard let mime = types[imageURL.pathExtension.lowercased()],
                      let attributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
                      let size = attributes[.size] as? Int, size <= 5_000_000,
                      let data = try? Data(contentsOf: imageURL) else { continue }
                html.replaceSubrange(range, with: "data:\(mime);base64,\(data.base64EncodedString())")
            }
            return ["index": index, "title": slide.title, "markdown": slide.markdown, "html": html,
                    "blocks": slide.codexBlocks.map { ["id": $0.id, "title": $0.title] }]
        }
        return ["theme": deck.theme.rawValue, "slides": slides]
    }
}
