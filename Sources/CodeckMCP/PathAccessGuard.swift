import CodeckCore
import Foundation

struct PathAccessGuard {
    let allowedRoots: [URL]
    private let pickedFiles: PickedFileGrants

    init(allowedRoots: [URL]) {
        self.allowedRoots = allowedRoots.map(Self.canonicalURLPreservingMissingPath)
        pickedFiles = PickedFileGrants(directory: self.allowedRoots[0].appendingPathComponent(".codeck-workspaces"))
    }

    /// Called only after an NSOpenPanel/NSSavePanel returns the user's selection.
    func grantPickedFile(_ url: URL) throws -> URL {
        let canonical = Self.canonicalURLPreservingMissingPath(url)
        guard ["mdeck", "md", "markdown"].contains(canonical.pathExtension.lowercased()) else {
            throw CodeckMCPError.invalidParams("Choose a Markdown presentation file.")
        }
        try pickedFiles.grant(canonical.path)
        return canonical
    }

    static func fromEnvironment() -> PathAccessGuard {
        let fileManager = FileManager.default
        let rawRoots = ProcessInfo.processInfo.environment["CODECK_MCP_ALLOWED_ROOTS"]?
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }

        let roots = rawRoots?.isEmpty == false ? rawRoots! : [fileManager.currentDirectoryPath]
        return PathAccessGuard(
            allowedRoots: roots.map { root in
                Self.canonicalURLPreservingMissingPath(
                    URL(fileURLWithPath: Self.expandTilde(root), relativeTo: nil)
                )
            }
        )
    }

    func resolve(_ path: String) throws -> URL {
        let expanded = Self.expandTilde(path)
        let url = if expanded.hasPrefix("/") {
            URL(fileURLWithPath: expanded)
        } else {
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(expanded)
        }

        let standardized = Self.canonicalURLPreservingMissingPath(url)
        guard allowedRoots.contains(where: { root in standardized.isInside(root) }) || pickedFiles.contains(standardized.path) else {
            let rootList = allowedRoots.map(\.path).joined(separator: ", ")
            throw CodeckMCPError.invalidParams("Path \(standardized.path) is outside the allowed roots: \(rootList).")
        }
        return standardized
    }

    private static func expandTilde(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    static func canonicalURLPreservingMissingPath(_ url: URL) -> URL {
        let fileManager = FileManager.default
        let standardized = url.standardizedFileURL
        if fileManager.fileExists(atPath: standardized.path) {
            return standardized.resolvingSymlinksInPath().standardizedFileURL
        }

        var remainingComponents: [String] = []
        var candidate = standardized
        while !fileManager.fileExists(atPath: candidate.path) {
            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else {
                return standardized
            }
            remainingComponents.append(candidate.lastPathComponent)
            candidate = parent
        }

        var resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        for component in remainingComponents.reversed() {
            resolved.appendPathComponent(component)
        }
        return resolved.standardizedFileURL
    }
}
