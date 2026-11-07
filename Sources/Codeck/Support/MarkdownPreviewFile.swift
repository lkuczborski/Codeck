import Foundation

/// A temporary document and its referenced assets, allowing WebKit a narrow file-read grant for movies.
final class MarkdownPreviewFile {
    let fileURL: URL
    let directoryURL: URL

    private struct LocalSource {
        let url: URL
        let fragment: String?
    }

    private struct Reference {
        let source: LocalSource
        let range: Range<String.Index>
        let isVideo: Bool
    }

    private init(directoryURL: URL) {
        self.directoryURL = directoryURL
        fileURL = directoryURL.appendingPathComponent("slide.html")
    }

    static func prepare(html: String, baseURL: URL?) throws -> MarkdownPreviewFile? {
        let references = localReferences(in: html, baseURL: baseURL)
        guard references.contains(where: \.isVideo) else { return nil }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CodeckPreview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let preview = MarkdownPreviewFile(directoryURL: directory)
        var renderedHTML = html
        var staged: [URL: URL] = [:]

        for reference in references.reversed() {
            let source = reference.source.url
            let asset: URL
            if let existing = staged[source] {
                asset = existing
            } else {
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: source.path),
                      attributes[.type] as? FileAttributeType == .typeRegular
                else { continue }
                var destination = directory.appendingPathComponent("media-\(staged.count)")
                if !source.pathExtension.isEmpty { destination.appendPathExtension(source.pathExtension) }
                do {
                    try FileManager.default.linkItem(at: source, to: destination)
                } catch {
                    do {
                        try FileManager.default.copyItem(at: source, to: destination)
                    } catch {
                        try? FileManager.default.removeItem(at: destination)
                        continue
                    }
                }
                staged[source] = destination
                asset = destination
            }
            var components = URLComponents(url: asset, resolvingAgainstBaseURL: false)
            components?.fragment = reference.source.fragment
            let sourceURL = components?.url?.absoluteString ?? asset.absoluteString
            renderedHTML.replaceSubrange(reference.range, with: escapeAttribute(sourceURL))
        }

        if let baseURL {
            let directoryBase = baseURL.isFileURL ? URL(fileURLWithPath: baseURL.path, isDirectory: true) : baseURL
            let base = "<base href=\"\(escapeAttribute(directoryBase.absoluteString))\">"
            if let head = renderedHTML.range(of: "<head>", options: .caseInsensitive) {
                renderedHTML.insert(contentsOf: base, at: head.upperBound)
            } else {
                renderedHTML = base + renderedHTML
            }
        }
        try renderedHTML.write(to: preview.fileURL, atomically: true, encoding: .utf8)
        return preview
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    deinit {
        cleanup()
    }

    private static func localReferences(in html: String, baseURL: URL?) -> [Reference] {
        guard let expression = try? NSRegularExpression(pattern: #"<(img|video)\b[^>]*?\bsrc="([^"]+)""#) else { return [] }
        return expression.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard let tagRange = Range(match.range(at: 1), in: html),
                  let sourceRange = Range(match.range(at: 2), in: html),
                  let source = localSource(unescapeAttribute(String(html[sourceRange])), baseURL: baseURL)
            else { return nil }
            return Reference(source: source, range: sourceRange, isVideo: html[tagRange] == "video")
        }
    }

    private static func localSource(_ source: String, baseURL: URL?) -> LocalSource? {
        guard let components = URLComponents(string: source), !source.hasPrefix("//") else { return nil }
        var encodedPath = String(source.prefix { $0 != "?" && $0 != "#" })
        if let scheme = components.scheme {
            guard scheme.lowercased() == "file", components.host == nil || components.host == "" || components.host == "localhost",
                  let colon = encodedPath.firstIndex(of: ":")
            else { return nil }
            encodedPath = String(encodedPath[encodedPath.index(after: colon)...])
            if encodedPath.hasPrefix("//") {
                let authority = encodedPath.dropFirst(2)
                guard let slash = authority.firstIndex(of: "/") else { return nil }
                encodedPath = String(authority[slash...])
            }
        } else {
            guard components.host == nil, baseURL?.isFileURL != false else { return nil }
        }
        // Decode the original path once; URLComponents can double-encode mixed raw/encoded filenames.
        let path = encodedPath.removingPercentEncoding ?? encodedPath
        guard !path.isEmpty else { return nil }
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            guard let baseURL, baseURL.isFileURL else { return nil }
            url = baseURL.appendingPathComponent(path)
        }
        let fragment = source.firstIndex(of: "#").map { String(source[source.index(after: $0)...]) }
        return LocalSource(
            url: url.standardizedFileURL.resolvingSymlinksInPath(),
            fragment: fragment.map { $0.removingPercentEncoding ?? $0 }
        )
    }

    private static func escapeAttribute(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func unescapeAttribute(_ value: String) -> String {
        value.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
