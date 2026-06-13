import AppKit
import Foundation

@MainActor
enum MarkdownEditorHighlighter {
    static let baseFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)

    static var baseTypingAttributes: [NSAttributedString.Key: Any] {
        [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
        ]
    }

    static func apply(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let selectedRanges = textView.selectedRanges
        textView.undoManager?.disableUndoRegistration()
        apply(to: textStorage, source: textView.string)
        textView.undoManager?.enableUndoRegistration()

        textView.typingAttributes = baseTypingAttributes
        textView.selectedRanges = selectedRanges.map { value in
            NSValue(range: clamped(value.rangeValue, length: (textView.string as NSString).length))
        }
    }

    static func apply(to textStorage: NSTextStorage, source: String) {
        let source = source as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()
        textStorage.setAttributes(baseTypingAttributes, range: fullRange)

        var codeBlock: CodeBlockState?
        source.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = source.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let state = codeBlock {
                applyCodeBlockAttributes(to: textStorage, lineRange: lineRange)
                if isClosingFence(trimmed, for: state) {
                    applyFenceAttributes(to: textStorage, lineRange: lineRange, line: line)
                    codeBlock = nil
                }
                return
            }

            if let fence = openingFence(in: line) {
                applyCodeBlockAttributes(to: textStorage, lineRange: lineRange)
                applyFenceAttributes(to: textStorage, lineRange: lineRange, line: line)
                codeBlock = fence
                return
            }

            applyLineMarkdownAttributes(to: textStorage, source: source, lineRange: lineRange, line: line)
            applyInlineMarkdownAttributes(to: textStorage, source: source, lineRange: lineRange)
        }

        textStorage.endEditing()
    }

    private static func applyLineMarkdownAttributes(
        to textStorage: NSTextStorage,
        source: NSString,
        lineRange: NSRange,
        line: String
    ) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let heading = match(headingRegex, in: line) {
            let level = heading.range(at: 1).length
            let contentRange = absoluteRange(heading.range(at: 2), in: lineRange)
            let markerRange = NSRange(location: lineRange.location, length: contentRange.location - lineRange.location)
            addAttributes(markerAttributes, to: textStorage, range: markerRange)
            addAttributes([
                .foregroundColor: NSColor.controlAccentColor,
                .font: NSFont.monospacedSystemFont(ofSize: headingFontSize(for: level), weight: .bold),
            ], to: textStorage, range: contentRange)
            return
        }

        if horizontalRuleRegex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil {
            addAttributes([
                .foregroundColor: NSColor.controlAccentColor,
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
            ], to: textStorage, range: lineRange)
            return
        }

        if let reference = match(referenceDefinitionRegex, in: line) {
            addAttributes(markerAttributes, to: textStorage, range: absoluteRange(reference.range(at: 1), in: lineRange))
            return
        }

        if let footnote = match(footnoteDefinitionRegex, in: line) {
            addAttributes(markerAttributes, to: textStorage, range: absoluteRange(footnote.range(at: 1), in: lineRange))
            return
        }

        if let blockquote = match(blockquoteRegex, in: line) {
            let markerRange = absoluteRange(blockquote.range(at: 1), in: lineRange)
            let quoteRange = NSRange(
                location: NSMaxRange(markerRange),
                length: max(0, NSMaxRange(lineRange) - NSMaxRange(markerRange))
            )
            addAttributes(markerAttributes, to: textStorage, range: markerRange)
            addAttributes([.foregroundColor: NSColor.secondaryLabelColor], to: textStorage, range: quoteRange)
            return
        }

        if let list = match(listRegex, in: line) {
            addAttributes(markerAttributes, to: textStorage, range: absoluteRange(list.range(at: 1), in: lineRange))
        }

        if let checkbox = match(taskCheckboxRegex, in: line) {
            addAttributes([
                .foregroundColor: NSColor.controlAccentColor,
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
            ], to: textStorage, range: absoluteRange(checkbox.range(at: 1), in: lineRange))
        }

        highlightTablePipes(in: textStorage, source: source, lineRange: lineRange, line: line)
    }

    private static func applyInlineMarkdownAttributes(
        to textStorage: NSTextStorage,
        source: NSString,
        lineRange: NSRange
    ) {
        var protectedRanges: [NSRange] = []

        for match in matches(inlineCodeRegex, source: source, range: lineRange) {
            let fullRange = match.range
            let contentRange = match.range(at: 1)
            addAttributes(markerAttributes, to: textStorage, range: fullRange)
            addAttributes(codeAttributes, to: textStorage, range: contentRange)
            protectedRanges.append(fullRange)
        }

        for match in matches(autolinkRegex, source: source, range: lineRange) where !intersects(match.range, protectedRanges) {
            let valueRange = match.range(at: 1)
            let openingRange = NSRange(location: match.range.location, length: valueRange.location - match.range.location)
            let closingRange = NSRange(location: NSMaxRange(valueRange), length: NSMaxRange(match.range) - NSMaxRange(valueRange))
            addAttributes(markerAttributes, to: textStorage, range: openingRange)
            addAttributes(markerAttributes, to: textStorage, range: closingRange)
            protectedRanges.append(valueRange)
        }

        for match in matches(linkRegex, source: source, range: lineRange) where !intersects(match.range, protectedRanges) {
            let prefixRange = match.range(at: 1)
            let titleRange = match.range(at: 2)
            let urlRange = match.range(at: 3)
            let openingBracketRange = NSRange(location: match.range.location + prefixRange.length, length: 1)
            addAttributes(markerAttributes, to: textStorage, range: prefixRange)
            addAttributes(markerAttributes, to: textStorage, range: openingBracketRange)
            addAttributes(markerAttributes, to: textStorage, range: NSRange(location: NSMaxRange(titleRange), length: 2))
            addAttributes(markerAttributes, to: textStorage, range: NSRange(location: NSMaxRange(urlRange), length: 1))
            addAttributes([
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ], to: textStorage, range: titleRange)
            protectedRanges.append(urlRange)
        }

        for match in matches(referenceLinkRegex, source: source, range: lineRange) where !intersects(match.range, protectedRanges) {
            let prefixRange = match.range(at: 1)
            let titleRange = match.range(at: 2)
            let labelRange = match.range(at: 3)
            let openingBracketRange = NSRange(location: match.range.location + prefixRange.length, length: 1)
            addAttributes(markerAttributes, to: textStorage, range: prefixRange)
            addAttributes(markerAttributes, to: textStorage, range: openingBracketRange)
            addAttributes(markerAttributes, to: textStorage, range: NSRange(location: NSMaxRange(titleRange), length: 2))
            addAttributes(markerAttributes, to: textStorage, range: NSRange(location: NSMaxRange(labelRange), length: 1))
            addAttributes([
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ], to: textStorage, range: titleRange)
            addAttributes([.foregroundColor: NSColor.secondaryLabelColor], to: textStorage, range: labelRange)
            protectedRanges.append(labelRange)
        }

        for match in matches(bareURLRegex, source: source, range: lineRange) where !intersects(match.range, protectedRanges) {
            protectedRanges.append(trimmedURLRange(match.range, source: source))
        }

        for match in matches(emailRegex, source: source, range: lineRange) where !intersects(match.range, protectedRanges) {
            protectedRanges.append(match.range)
        }

        for match in matches(htmlTagRegex, source: source, range: lineRange) where !intersects(match.range, protectedRanges) {
            addAttributes([
                .foregroundColor: NSColor.systemOrange,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            ], to: textStorage, range: match.range)
            protectedRanges.append(match.range)
        }

        applyDelimitedStyle(
            regex: strongEmphasisAsteriskRegex,
            textStorage: textStorage,
            source: source,
            lineRange: lineRange,
            protectedRanges: protectedRanges
        ) { range in
            addFontTrait(.boldFontMask, to: textStorage, range: range)
            addFontTrait(.italicFontMask, to: textStorage, range: range)
        }

        applyDelimitedStyle(
            regex: strongEmphasisUnderscoreRegex,
            textStorage: textStorage,
            source: source,
            lineRange: lineRange,
            protectedRanges: protectedRanges
        ) { range in
            addFontTrait(.boldFontMask, to: textStorage, range: range)
            addFontTrait(.italicFontMask, to: textStorage, range: range)
        }

        applyDelimitedStyle(
            regex: strongAsteriskRegex,
            textStorage: textStorage,
            source: source,
            lineRange: lineRange,
            protectedRanges: protectedRanges
        ) { range in
            addFontTrait(.boldFontMask, to: textStorage, range: range)
        }

        applyDelimitedStyle(
            regex: strongUnderscoreRegex,
            textStorage: textStorage,
            source: source,
            lineRange: lineRange,
            protectedRanges: protectedRanges
        ) { range in
            addFontTrait(.boldFontMask, to: textStorage, range: range)
        }

        applyDelimitedStyle(
            regex: emphasisAsteriskRegex,
            textStorage: textStorage,
            source: source,
            lineRange: lineRange,
            protectedRanges: protectedRanges
        ) { range in
            addFontTrait(.italicFontMask, to: textStorage, range: range)
        }

        applyDelimitedStyle(
            regex: emphasisUnderscoreRegex,
            textStorage: textStorage,
            source: source,
            lineRange: lineRange,
            protectedRanges: protectedRanges
        ) { range in
            addFontTrait(.italicFontMask, to: textStorage, range: range)
        }

        applyDelimitedStyle(
            regex: strikethroughRegex,
            textStorage: textStorage,
            source: source,
            lineRange: lineRange,
            protectedRanges: protectedRanges
        ) { range in
            addAttributes([.strikethroughStyle: NSUnderlineStyle.single.rawValue], to: textStorage, range: range)
        }
    }

    private static func applyDelimitedStyle(
        regex: NSRegularExpression,
        textStorage: NSTextStorage,
        source: NSString,
        lineRange: NSRange,
        protectedRanges: [NSRange],
        applyStyle: (NSRange) -> Void
    ) {
        for match in matches(regex, source: source, range: lineRange) where !intersects(match.range, protectedRanges) {
            let contentRange = match.range(at: 1)
            let openingRange = NSRange(location: match.range.location, length: contentRange.location - match.range.location)
            let closingRange = NSRange(
                location: NSMaxRange(contentRange),
                length: NSMaxRange(match.range) - NSMaxRange(contentRange)
            )
            addAttributes(markerAttributes, to: textStorage, range: openingRange)
            addAttributes(markerAttributes, to: textStorage, range: closingRange)
            applyStyle(contentRange)
        }
    }

    private static func applyCodeBlockAttributes(to textStorage: NSTextStorage, lineRange: NSRange) {
        addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.systemPink,
            .backgroundColor: CodeckPalette.inlineCodeBackgroundNSColor,
        ], to: textStorage, range: lineRange)
    }

    private static func applyFenceAttributes(to textStorage: NSTextStorage, lineRange: NSRange, line: String) {
        guard let match = match(fenceRegex, in: line) else { return }
        addAttributes(markerAttributes, to: textStorage, range: absoluteRange(match.range(at: 2), in: lineRange))

        let infoRange = absoluteRange(match.range(at: 3), in: lineRange)
        guard infoRange.length > 0 else { return }
        addAttributes([
            .foregroundColor: NSColor.systemTeal,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
        ], to: textStorage, range: infoRange)
    }

    private static func highlightTablePipes(
        in textStorage: NSTextStorage,
        source _: NSString,
        lineRange: NSRange,
        line: String
    ) {
        guard line.contains("|") else { return }

        let lineSource = line as NSString
        var searchLocation = 0
        while searchLocation < lineSource.length {
            let range = lineSource.range(of: "|", range: NSRange(location: searchLocation, length: lineSource.length - searchLocation))
            guard range.location != NSNotFound else { break }
            addAttributes(markerAttributes, to: textStorage, range: absoluteRange(range, in: lineRange))
            searchLocation = NSMaxRange(range)
        }
    }

    private static func openingFence(in line: String) -> CodeBlockState? {
        guard let match = match(fenceRegex, in: line) else { return nil }
        let marker = (line as NSString).substring(with: match.range(at: 2))
        return CodeBlockState(marker: marker)
    }

    private static func isClosingFence(_ trimmedLine: String, for state: CodeBlockState) -> Bool {
        guard trimmedLine.hasPrefix(String(repeating: String(state.marker.first ?? "`"), count: state.marker.count)) else {
            return false
        }

        return trimmedLine.allSatisfy { character in
            character == state.marker.first || character.isWhitespace
        }
    }

    private static func addAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        to textStorage: NSTextStorage,
        range: NSRange
    ) {
        guard range.location != NSNotFound,
              range.length > 0,
              NSMaxRange(range) <= textStorage.length
        else {
            return
        }
        textStorage.addAttributes(attributes, range: range)
    }

    private static func addFontTrait(_ trait: NSFontTraitMask, to textStorage: NSTextStorage, range: NSRange) {
        guard range.location != NSNotFound,
              range.length > 0,
              NSMaxRange(range) <= textStorage.length
        else {
            return
        }

        var updates: [(range: NSRange, font: NSFont)] = []
        textStorage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = value as? NSFont ?? baseFont
            let converted = NSFontManager.shared.convert(font, toHaveTrait: trait)
            updates.append((subrange, converted))
        }

        for update in updates {
            textStorage.addAttribute(.font, value: update.font, range: update.range)
        }
    }

    private static func matches(
        _ regex: NSRegularExpression,
        source: NSString,
        range: NSRange
    ) -> [NSTextCheckingResult] {
        regex.matches(in: source as String, range: range)
    }

    private static func match(_ regex: NSRegularExpression, in line: String) -> NSTextCheckingResult? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        return regex.firstMatch(in: line, range: range)
    }

    private static func absoluteRange(_ range: NSRange, in lineRange: NSRange) -> NSRange {
        guard range.location != NSNotFound else { return range }
        return NSRange(location: lineRange.location + range.location, length: range.length)
    }

    private static func trimmedURLRange(_ range: NSRange, source: NSString) -> NSRange {
        var length = range.length
        while length > 0 {
            let characterRange = NSRange(location: range.location + length - 1, length: 1)
            let character = source.substring(with: characterRange)
            guard trailingURLPunctuation.contains(character) else { break }
            length -= 1
        }
        return NSRange(location: range.location, length: length)
    }

    private static func intersects(_ range: NSRange, _ protectedRanges: [NSRange]) -> Bool {
        protectedRanges.contains { NSIntersectionRange(range, $0).length > 0 }
    }

    private static func clamped(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(range.location, 0), length)
        let upperBound = min(max(range.location + range.length, location), length)
        return NSRange(location: location, length: upperBound - location)
    }

    private static func headingFontSize(for level: Int) -> CGFloat {
        switch level {
        case 1:
            18
        case 2:
            16
        default:
            15
        }
    }

    private static let markerAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.tertiaryLabelColor,
    ]

    private static let codeAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor.systemPink,
        .backgroundColor: CodeckPalette.inlineCodeBackgroundNSColor,
    ]

    private struct CodeBlockState {
        var marker: String
    }

    private static let fenceRegex = regularExpression(pattern: #"^(\s*)(`{3,}|~{3,})(.*)$"#)
    private static let headingRegex = regularExpression(pattern: #"^\s*(#{1,6})\s+(.+)$"#)
    private static let horizontalRuleRegex = regularExpression(pattern: #"^\s*(\*\s*){3,}$|^\s*(_\s*){3,}$|^\s*(-\s*){3,}$"#)
    private static let referenceDefinitionRegex = regularExpression(pattern: #"^\s{0,3}(\[[^\]\n]+\]:)\s*(\S+)"#)
    private static let footnoteDefinitionRegex = regularExpression(pattern: #"^\s{0,3}(\[\^[^\]\n]+\]:)"#)
    private static let blockquoteRegex = regularExpression(pattern: #"^\s*(>\s?)"#)
    private static let listRegex = regularExpression(pattern: #"^\s*((?:[-+*]|\d+\.)\s+)"#)
    private static let taskCheckboxRegex = regularExpression(pattern: #"^\s*(?:[-+*]|\d+\.)\s+(\[[ xX]\])\s+"#)
    private static let inlineCodeRegex = regularExpression(pattern: #"`([^`\n]+)`"#)
    private static let autolinkRegex = regularExpression(
        pattern: #"<((?:https?://|mailto:)[^>\s]+|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})>"#,
        options: [.caseInsensitive]
    )
    private static let linkRegex = regularExpression(pattern: #"(!?)\[([^\]\n]+)\]\(([^\)\n]+)\)"#)
    private static let referenceLinkRegex = regularExpression(pattern: #"(!?)\[([^\]\n]+)\]\[([^\]\n]*)\]"#)
    private static let bareURLRegex = regularExpression(pattern: #"\b(?:https?://|www\.)[^\s<>\[\]{}"']+"#, options: [.caseInsensitive])
    private static let emailRegex = regularExpression(
        pattern: #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
        options: [.caseInsensitive]
    )
    private static let htmlTagRegex = regularExpression(pattern: #"<!--.*?-->|</?[A-Za-z][A-Za-z0-9-]*(?:\s+[^<>\n]*)?>"#)
    private static let strongEmphasisAsteriskRegex = regularExpression(pattern: #"(?<!\*)\*\*\*([^\*\n]+)\*\*\*(?!\*)"#)
    private static let strongEmphasisUnderscoreRegex = regularExpression(pattern: #"(?<!_)___([^_\n]+)___(?!_)"#)
    private static let strongAsteriskRegex = regularExpression(pattern: #"(?<!\*)\*\*([^\*\n]+)\*\*(?!\*)"#)
    private static let strongUnderscoreRegex = regularExpression(pattern: #"(?<!_)__([^_\n]+)__(?!_)"#)
    private static let emphasisAsteriskRegex = regularExpression(pattern: #"(?<!\*)\*([^\*\n]+)\*(?!\*)"#)
    private static let emphasisUnderscoreRegex = regularExpression(pattern: #"(?<!_)_([^_\n]+)_(?!_)"#)
    private static let strikethroughRegex = regularExpression(pattern: #"~~([^~\n]+)~~"#)
    private static let trailingURLPunctuation = Set([".", ",", ";", ":", "!", "?", ")", "]", "}"])

    private static func regularExpression(
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            preconditionFailure("Invalid Markdown editor regex pattern: \(pattern)")
        }
    }
}
