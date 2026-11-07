import Foundation

/// Parses Markdown media before HTML escaping, so destinations remain independent of formatting.
struct MarkdownMedia {
    struct Match {
        let media: MarkdownMedia
        let range: Range<String.Index>
    }

    let altText: String
    let destination: String
    let title: String?

    var isVideo: Bool {
        let fallbackPath = String(destination.prefix { $0 != "?" && $0 != "#" })
        let path = URLComponents(string: destination)?.path ?? fallbackPath.removingPercentEncoding ?? fallbackPath
        let pathExtension = (path as NSString).pathExtension.lowercased()
        return ["mp4", "m4v", "mov", "webm"].contains(pathExtension)
    }

    var isBackground: Bool {
        altText == "bg" || altText.hasPrefix("bg ") || altText.hasPrefix("bg\t")
    }

    var backgroundDescription: String {
        isBackground ? String(altText.dropFirst(2)).trimmingCharacters(in: .whitespaces) : altText
    }

    /// Call only for a top-level block, never for list items, quotes, or generated output.
    static func background(in line: String) -> MarkdownMedia? {
        let indentation = line.prefix { $0 == " " }
        guard indentation.count <= 3 else { return nil }
        let trimmed = String(line.dropFirst(indentation.count)).trimmingCharacters(in: .whitespaces)
        guard !line.dropFirst(indentation.count).hasPrefix("\t"),
              let match = parse(in: trimmed, at: trimmed.startIndex),
              match.range.upperBound == trimmed.endIndex,
              match.media.isBackground,
              !match.media.isVideo
        else {
            return nil
        }
        return match.media
    }

    static func parse(in text: String, at start: String.Index) -> Match? {
        guard start < text.endIndex, text[start...].hasPrefix("![") else { return nil }
        var index = text.index(start, offsetBy: 2)
        guard let altText = readDelimited(in: text, index: &index, opening: "[", closing: "]"),
              index < text.endIndex, text[index] == "("
        else {
            return nil
        }
        index = text.index(after: index)
        skipWhitespace(in: text, index: &index)
        guard let destination = readDestination(in: text, index: &index) else { return nil }

        let destinationEnd = index
        skipWhitespace(in: text, index: &index)
        var title: String?
        if index < text.endIndex, text[index] != ")" {
            guard destinationEnd != index else { return nil }
            let delimiter = text[index]
            guard delimiter == "\"" || delimiter == "'" || delimiter == "(" else { return nil }
            index = text.index(after: index)
            guard let parsedTitle = readDelimited(
                in: text,
                index: &index,
                opening: delimiter == "(" ? "(" : nil,
                closing: delimiter == "(" ? ")" : delimiter
            ) else { return nil }
            title = parsedTitle
            skipWhitespace(in: text, index: &index)
        }
        guard index < text.endIndex, text[index] == ")" else { return nil }
        index = text.index(after: index)
        return Match(media: MarkdownMedia(altText: altText, destination: destination, title: title), range: start ..< index)
    }

    private static func readDestination(in text: String, index: inout String.Index) -> String? {
        guard index < text.endIndex else { return nil }
        if text[index] == "<" {
            index = text.index(after: index)
            return readDelimited(in: text, index: &index, opening: nil, closing: ">", forbidden: "<")
        }

        var destination = ""
        var depth = 0
        while index < text.endIndex {
            let character = text[index]
            if character.isWhitespace || (character == ")" && depth == 0) { break }
            if character == "<" { return nil }
            if appendEscape(in: text, index: &index, to: &destination) { continue }
            if character == "(" { depth += 1 }
            if character == ")" { depth -= 1 }
            destination.append(character)
            index = text.index(after: index)
        }
        return depth == 0 ? destination : nil
    }

    private static func readDelimited(
        in text: String,
        index: inout String.Index,
        opening: Character?,
        closing: Character,
        forbidden: Character? = nil
    ) -> String? {
        var result = ""
        var depth = 0
        while index < text.endIndex {
            let character = text[index]
            if character.isNewline || character == forbidden { return nil }
            if appendEscape(in: text, index: &index, to: &result) { continue }
            if character == closing, depth == 0 {
                index = text.index(after: index)
                return result
            }
            if character == opening { depth += 1 }
            if character == closing { depth -= 1 }
            result.append(character)
            index = text.index(after: index)
        }
        return nil
    }

    private static func appendEscape(in text: String, index: inout String.Index, to result: inout String) -> Bool {
        guard text[index] == "\\", let next = nextIndex(in: text, after: index), isEscapable(text[next]) else { return false }
        result.append(text[next])
        index = text.index(after: next)
        return true
    }

    static func isEscapable(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let value = character.unicodeScalars.first?.value else { return false }
        return (33 ... 47).contains(value) || (58 ... 64).contains(value) || (91 ... 96).contains(value) || (123 ... 126).contains(value)
    }

    private static func skipWhitespace(in text: String, index: inout String.Index) {
        while index < text.endIndex, text[index] == " " || text[index] == "\t" {
            index = text.index(after: index)
        }
    }

    private static func nextIndex(in text: String, after index: String.Index) -> String.Index? {
        let next = text.index(after: index)
        return next < text.endIndex ? next : nil
    }

    static func codeSpanEnd(in text: String, at start: String.Index) -> String.Index? {
        let markerLength = text[start...].prefix { $0 == "`" }.count
        var index = text.index(start, offsetBy: markerLength)
        while index < text.endIndex {
            if text[index] == "`" {
                let length = text[index...].prefix { $0 == "`" }.count
                index = text.index(index, offsetBy: length)
                if length == markerLength { return index }
            } else {
                index = text.index(after: index)
            }
        }
        return nil
    }
}
