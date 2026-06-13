import Foundation

extension URL {
    func isInside(_ root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let path = standardizedFileURL.path
        return rootPath == "/" || path == rootPath || path.hasPrefix(rootPath + "/")
    }
}
