import Foundation

/// Persist exact file grants across plugin restarts, without authorizing parent folders.
final class PickedFileGrants {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func contains(_ path: String) -> Bool {
        load().contains(path)
    }

    func grant(_ path: String) throws {
        try validateLocation()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try validateLocation()
        var files = load()
        files.insert(path)
        try JSONEncoder().encode(files.sorted()).write(to: url, options: .atomic)
    }

    private func validateLocation() throws {
        let root = directory.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let expected = root.appendingPathComponent(directory.lastPathComponent)
        guard PathAccessGuard.canonicalURLPreservingMissingPath(directory).path == expected.path,
              PathAccessGuard.canonicalURLPreservingMissingPath(url).path == expected.appendingPathComponent("picked-files.json").path
        else {
            throw CodeckMCPError.invalidParams("The selected-file grant store cannot contain symbolic links.")
        }
    }

    private var url: URL {
        directory.appendingPathComponent("picked-files.json")
    }

    private func load() -> Set<String> {
        guard (try? validateLocation()) != nil else { return [] }
        guard let data = try? Data(contentsOf: url), let files = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(files)
    }
}
