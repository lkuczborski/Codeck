import Foundation

enum MarkdownInlineRenderer {
    static func render(_ text: String) -> String {
        // Keep code, escaped punctuation and generated tags opaque to later formatting passes.
        var prefix = "\u{E000}codeck"
        while text.contains(prefix) {
            prefix.append("x")
        }
        var protected: [String] = []
        var markupTokens: Set<String> = []
        func token(_ html: String, isLiteral: Bool = false) -> String {
            protected.append(html)
            let placeholder = "\(prefix)\(protected.count - 1)\u{E001}"
            if !isLiteral { markupTokens.insert(placeholder) }
            return placeholder
        }

        var source = ""
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if text[index] == "\\", next < text.endIndex, MarkdownMedia.isEscapable(text[next]) {
                source += token(escape(String(text[next])), isLiteral: true)
                index = text.index(after: next)
            } else if text[index] == "`" {
                let count = text[index...].prefix { $0 == "`" }.count
                let start = text.index(index, offsetBy: count)
                guard let end = MarkdownMedia.codeSpanEnd(in: text, at: index) else {
                    source += text[index ..< start]
                    index = start
                    continue
                }
                let contentEnd = text.index(end, offsetBy: -count)
                var code = String(text[start ..< contentEnd])
                if code.hasPrefix(" "), code.hasSuffix(" "), code.contains(where: { $0 != " " }) {
                    code.removeFirst()
                    code.removeLast()
                }
                source += token("<code>\(escape(code))</code>")
                index = end
            } else if let match = MarkdownMedia.parse(in: text, at: index) {
                source += token(renderMedia(match.media))
                index = match.range.upperBound
            } else {
                source.append(text[index])
                index = next
            }
        }

        var html = escape(source)
        html = replace(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", in: html) { matches in
            // Restored media/code belongs in text or link labels, never inside an HTML attribute.
            guard !markupTokens.contains(where: { matches[2].contains($0) }) else { return matches[0] }
            return "<a href=\"\(matches[2])\">\(matches[1])</a>"
        }
        html = replace(pattern: "~~([^~]+)~~", in: html) { "<del>\($0[1])</del>" }
        html = replace(pattern: "\\*\\*([^*]+)\\*\\*", in: html) { "<strong>\($0[1])</strong>" }
        html = replace(pattern: "\\*([^*]+)\\*", in: html) { "<em>\($0[1])</em>" }
        for (index, value) in protected.enumerated() {
            html = html.replacingOccurrences(of: "\(prefix)\(index)\u{E001}", with: value)
        }
        return html
    }

    private static func renderMedia(_ media: MarkdownMedia) -> String {
        let source = escape(media.destination)
        let description = escape(media.altText)
        let title = media.title.map { " title=\"\(escape($0))\"" } ?? ""
        if media.isVideo {
            return "<video src=\"\(source)\" aria-label=\"\(description)\"\(title) controls playsinline preload=\"auto\"></video>"
        }
        return "<img src=\"\(source)\" alt=\"\(description)\"\(title)>"
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func replace(pattern: String, in text: String, transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        var result = text
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed() {
            let groups = (0 ..< match.numberOfRanges).map { index in
                match.range(at: index).location == NSNotFound ? "" : nsText.substring(with: match.range(at: index))
            }
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: transform(groups))
            }
        }
        return result
    }
}
