import Foundation

enum CodeckMCPMediaAssets {
    private static let maximumBytes = 5_000_000
    private static let imageTypes = ["png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp"]
    private static let videoTypes = ["mp4": "video/mp4", "m4v": "video/mp4", "mov": "video/quicktime", "webm": "video/webm"]

    /// The isolated MCP App receives only authorized local assets, within the existing per-file limit.
    static func embeddingLocalSources(in renderedHTML: String, directory: URL?, paths: PathAccessGuard) -> String {
        guard let directory,
              let expression = try? NSRegularExpression(pattern: #"<(img|video)\b[^>]*?\bsrc="([^"]+)""#)
        else { return renderedHTML }
        var html = renderedHTML
        for match in expression.matches(in: html, range: NSRange(html.startIndex..., in: html)).reversed() {
            guard let tagRange = Range(match.range(at: 1), in: html),
                  let sourceRange = Range(match.range(at: 2), in: html)
            else { continue }
            let source = unescapeAttribute(String(html[sourceRange]))
            guard let components = URLComponents(string: source), components.scheme == nil, components.host == nil,
                  !source.hasPrefix("//")
            else { continue }
            // URLComponents re-encodes existing percent escapes when the source also contains a raw quote.
            // Decode the original path exactly once so mixed encoded/raw filenames still resolve correctly.
            let encodedPath = String(source.prefix { $0 != "?" && $0 != "#" })
            let path = encodedPath.removingPercentEncoding ?? encodedPath
            guard !path.isEmpty else { continue }
            let rawPath = path.hasPrefix("/") ? path : directory.appendingPathComponent(path).path
            guard let url = try? paths.resolve(rawPath) else { continue }
            let types = html[tagRange] == "video" ? videoTypes : imageTypes
            guard let mime = types[url.pathExtension.lowercased()],
                  let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? Int, size <= maximumBytes,
                  let data = try? Data(contentsOf: url), data.count <= maximumBytes
            else { continue }
            let fragment = components.percentEncodedFragment.map { "#" + $0.replacingOccurrences(of: "&", with: "&amp;") } ?? ""
            html.replaceSubrange(sourceRange, with: "data:\(mime);base64,\(data.base64EncodedString())\(fragment)")
        }
        return html
    }

    private static func unescapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
