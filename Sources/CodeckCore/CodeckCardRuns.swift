import Foundation

public struct CodeckCardRun: Codable, Sendable {
    public var id: String
    public var workspaceID: String
    public var blockID: String
    public var fingerprint: String
    public var prompt: String
    public var title: String
    public var sandbox: String
    public var model: String
    public var reasoning: String
    public var profile: String?
    public var status: String
    public var route: String?
    public var output: String
}

/// Results belong to a validated card and a unique run, never to arbitrary renderer HTML.
public final class CodeckCardRuns: @unchecked Sendable {
    private let lock = NSLock()
    private var runs: [CodeckCardRun] = []
    private var version = 0

    public init() {}

    public static func fingerprint(_ block: CodexBlock, settings: DeckCodexSettings = .default) -> String {
        DeckWorkspace.digest([
            block.id,
            block.prompt,
            block.model ?? settings.model,
            (block.reasoning ?? settings.reasoning).rawValue,
            block.sandbox ?? settings.sandbox,
            block.profile ?? "",
        ].joined(separator: "\u{0}"))
    }

    public func begin(workspace: DeckWorkspace, slideIndex: Int, blockID: String) throws -> CodeckCardRun {
        let deck = PresentationDeck(markdownDocument: workspace.markdown)
        guard deck.slides.indices.contains(slideIndex), let block = deck.slides[slideIndex].codexBlocks.first(where: { $0.id == blockID }) else {
            throw CodeckWorkspaceError.invalid("That Codex card is no longer on this slide.")
        }
        guard deck.slides.flatMap(\.codexBlocks).count(where: { $0.id == blockID }) == 1 else {
            throw CodeckWorkspaceError.invalid("Give each Codex card a unique id before running it.")
        }
        return lock.withLock {
            if let existing = runs.last(where: { $0.workspaceID == workspace.id && $0.blockID == blockID && ["queued", "running"].contains($0.status) }) {
                if existing.fingerprint == Self.fingerprint(block, settings: deck.settings.codex) { return existing }
                if let index = runs.firstIndex(where: { $0.id == existing.id }) { runs[index].status = "stopped" }
            }
            let settings = deck.settings.codex
            let sandbox = block.sandbox ?? settings.sandbox
            let run = CodeckCardRun(
                id: UUID().uuidString,
                workspaceID: workspace.id,
                blockID: blockID,
                fingerprint: Self.fingerprint(block, settings: settings),
                prompt: block.prompt,
                title: block.title,
                sandbox: sandbox,
                model: block.model ?? settings.model,
                reasoning: (block.reasoning ?? settings.reasoning).rawValue,
                profile: block.profile,
                status: "running",
                route: "native",
                output: ""
            )
            runs.append(run)
            version += 1
            return run
        }
    }

    public func snapshot(_ workspaceID: String) -> (version: Int, runs: [CodeckCardRun]) {
        lock.withLock { (version, runs.filter { $0.workspaceID == workspaceID }) }
    }

    public func stop(_ id: String) {
        lock.withLock {
            guard let index = runs.firstIndex(where: { $0.id == id }), ["queued", "running"].contains(runs[index].status) else { return }
            runs[index].status = "stopped"
            version += 1
        }
    }

    public func run(_ id: String) -> CodeckCardRun? {
        lock.withLock { runs.first { $0.id == id } }
    }

    public func updateNative(_ id: String, output: CodexSessionOutput) {
        lock.withLock {
            guard let index = runs.firstIndex(where: { $0.id == id }), runs[index].status == "running", runs[index].route == "native" else { return }
            // Match the Mac app: diagnostic stderr is never a model response.
            let text = String(CodexSessionOutputFormatter.markdown(from: output).prefix(200_000))
            guard runs[index].output != text || runs[index].status != output.state.rawValue else { return }
            runs[index].output = text
            runs[index].status = output.state.rawValue
            version += 1
        }
    }

    public func outputs(_ workspaceID: String, blocks: [CodexBlock], settings: DeckCodexSettings = .default) -> [String: CodexSessionOutput] {
        lock.withLock {
            var outputs: [String: CodexSessionOutput] = [:]
            for block in blocks {
                guard let run = runs.last(where: { $0.workspaceID == workspaceID && $0.blockID == block.id && $0.fingerprint == Self.fingerprint(
                    block,
                    settings: settings
                ) }) else { continue }
                let state = run.status == "queued" ? CodexSessionState.running : CodexSessionState(rawValue: run.status) ?? .idle
                outputs[block.id] = CodexSessionOutput(state: state, text: run.output, standardOutput: run.output)
            }
            return outputs
        }
    }
}
