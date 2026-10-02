import CryptoKit
import Darwin
import Foundation

public struct DeckWorkspace: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var markdown: String
    public var path: String?
    public var revision: Int
    public var savedDigest: String?
    public var diskConflict: Bool
    public var updatedAt: Date

    public var dirty: Bool {
        Self.digest(markdown) != savedDigest
    }

    public static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public enum CodeckWorkspaceError: LocalizedError {
    case invalid(String)
    case conflict
    case diskConflict
    case existingFile

    public var errorDescription: String? {
        switch self {
        case let .invalid(message): message
        case .conflict: "The workspace changed. Read it again and reapply your edit to the latest revision."
        case .diskConflict: "The deck changed on disk. Save a copy or reload before saving."
        case .existingFile: "That file already exists. Choose another path or explicitly allow overwrite."
        }
    }
}

/// Drafts persist independently of the presentation file. All paths, including
/// internal state files, pass through the MCP server's canonical path authorization.
public final class CodeckWorkspaceStore {
    public typealias PathResolver = (String) throws -> URL
    private let directory: URL
    private let resolve: PathResolver

    public init(directory: URL, resolve: @escaping PathResolver) {
        self.directory = directory
        self.resolve = resolve
    }

    public func open(path: String? = nil, markdown: String? = nil, title: String = "Untitled deck") throws -> DeckWorkspace {
        try locked {
            if let path {
                let url = try deckURL(path)
                for workspace in try listUnlocked() where workspace.path == url.path {
                    return try refresh(workspace)
                }
                let source = try String(contentsOf: url, encoding: .utf8)
                return try create(source, path: url.path, title: url.deletingPathExtension().lastPathComponent, saved: true)
            }
            return try create(markdown ?? "# Untitled\n", path: nil, title: title, saved: false)
        }
    }

    public func list() throws -> [DeckWorkspace] {
        try locked { try listUnlocked() }
    }

    public func read(_ id: String) throws -> DeckWorkspace {
        try locked { try refresh(load(id)) }
    }

    public func update(_ id: String, revision: Int, markdown: String) throws -> DeckWorkspace {
        try locked {
            var state = try checked(id, revision: revision)
            try validate(markdown)
            state.markdown = markdown
            return try commit(state)
        }
    }

    public func save(_ id: String, revision: Int, path: String? = nil, overwrite: Bool = false) throws -> DeckWorkspace {
        try locked {
            var state = try checked(id, revision: revision)
            guard let path = path ?? state.path else { throw CodeckWorkspaceError.invalid("Choose a path for this deck first.") }
            let url = try deckURL(path)
            if FileManager.default.fileExists(atPath: url.path) {
                if url.path == state.path {
                    let disk = try String(contentsOf: url, encoding: .utf8)
                    guard DeckWorkspace.digest(disk) == state.savedDigest else { throw CodeckWorkspaceError.diskConflict }
                } else if !overwrite {
                    throw CodeckWorkspaceError.existingFile
                }
            } else if url.path == state.path, state.savedDigest != nil {
                throw CodeckWorkspaceError.diskConflict
            }
            try Data(state.markdown.utf8).write(to: url, options: .atomic)
            state.path = url.path
            state.title = url.deletingPathExtension().lastPathComponent
            state.savedDigest = DeckWorkspace.digest(state.markdown)
            state.diskConflict = false
            return try commit(state)
        }
    }

    /// Explicitly discards a draft in favor of the file on disk.
    public func reload(_ id: String, revision: Int) throws -> DeckWorkspace {
        try locked {
            var state = try checked(id, revision: revision)
            guard let path = state.path else { throw CodeckWorkspaceError.invalid("This draft has no disk file.") }
            state.markdown = try String(contentsOf: deckURL(path), encoding: .utf8)
            state.savedDigest = DeckWorkspace.digest(state.markdown)
            state.diskConflict = false
            return try commit(state)
        }
    }

    private func create(_ markdown: String, path: String?, title: String, saved: Bool) throws -> DeckWorkspace {
        try validate(markdown)
        let state = DeckWorkspace(
            id: UUID().uuidString, title: title, markdown: markdown, path: path, revision: 0,
            savedDigest: saved ? DeckWorkspace.digest(markdown) : nil, diskConflict: false, updatedAt: Date()
        )
        try persist(state)
        return state
    }

    private func refresh(_ state: DeckWorkspace) throws -> DeckWorkspace {
        guard let path = state.path else { return state }
        let url = try deckURL(path)
        var state = state
        guard FileManager.default.fileExists(atPath: url.path) else {
            if !state.diskConflict {
                state.diskConflict = true
                return try commit(state)
            }
            return state
        }
        let disk = try String(contentsOf: url, encoding: .utf8)
        let changed = DeckWorkspace.digest(disk) != state.savedDigest
        if changed, !state.dirty {
            try validate(disk)
            state.markdown = disk
            state.savedDigest = DeckWorkspace.digest(disk)
            state.diskConflict = false
            return try commit(state)
        }
        if state.diskConflict != changed {
            state.diskConflict = changed
            return try commit(state)
        }
        return state
    }

    private func checked(_ id: String, revision: Int) throws -> DeckWorkspace {
        let state = try refresh(load(id))
        guard state.revision == revision else { throw CodeckWorkspaceError.conflict }
        return state
    }

    private func commit(_ state: DeckWorkspace) throws -> DeckWorkspace {
        var state = state
        state.revision += 1
        state.updatedAt = Date()
        try persist(state)
        return state
    }

    private func persist(_ state: DeckWorkspace) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(state).write(to: stateURL(state.id), options: .atomic)
    }

    private func load(_ id: String) throws -> DeckWorkspace {
        try JSONDecoder().decode(DeckWorkspace.self, from: Data(contentsOf: stateURL(id)))
    }

    private func listUnlocked() throws -> [DeckWorkspace] {
        try FileManager.default.contentsOfDirectory(at: resolve(directory.path), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .compactMap { try? load($0.deletingPathExtension().lastPathComponent) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func stateURL(_ id: String) throws -> URL {
        guard UUID(uuidString: id) != nil else { throw CodeckWorkspaceError.invalid("Invalid workspace ID.") }
        return try resolve(directory.appendingPathComponent("\(id).json").path)
    }

    private func deckURL(_ path: String) throws -> URL {
        let url = try resolve(path)
        guard ["mdeck", "md", "markdown"].contains(url.pathExtension.lowercased()) else {
            throw CodeckWorkspaceError.invalid("Deck paths must end with .mdeck, .md, or .markdown.")
        }
        return url
    }

    private func validate(_ markdown: String) throws {
        guard markdown.utf8.count <= 2_000_000 else { throw CodeckWorkspaceError.invalid("Decks are limited to 2 MB in the workspace.") }
    }

    private func locked<T>(_ operation: () throws -> T) throws -> T {
        let directory = try resolve(directory.path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockURL = try resolve(directory.appendingPathComponent("workspace.lock").path)
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw CodeckWorkspaceError.invalid("Could not open workspace lock.") }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CodeckWorkspaceError.invalid("Could not lock workspace storage.") }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }
}
