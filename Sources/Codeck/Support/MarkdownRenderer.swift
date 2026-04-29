import Foundation

enum MarkdownRenderer {
  private enum ListKind {
    case ordered
    case unordered
  }

  private struct ListMarker {
    var kind: ListKind
    var start: Int?
    var text: String
  }

  static func htmlDocument(
    for slide: Slide,
    theme: PresentationTheme,
    codexOutputs: [String: CodexSessionOutput]
  ) -> String {
    let codexBlocks = slide.codexBlocks
    let body = renderBlocks(from: slide.markdown, codexOutputs: codexOutputs)
    return
      """
      <!doctype html>
      <html>
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
      \(theme.css)
      \(baseCSS)
      </style>
      <script>
      window.Codeck = {
        runCodex: function(id) {
          window.webkit?.messageHandlers?.codeck?.postMessage({ action: "runCodex", id: id });
        },
        stopCodex: function(id) {
          window.webkit?.messageHandlers?.codeck?.postMessage({ action: "stopCodex", id: id });
        },
        runAllCodex: function() {
          window.webkit?.messageHandlers?.codeck?.postMessage({ action: "runAllCodex" });
        }
      };
      </script>
      </head>
      <body>
        <main class="slide">
          \(renderSlideActions(for: codexBlocks))
          \(body)
        </main>
      </body>
      </html>
      """
  }

  private static func renderBlocks(
    from markdown: String,
    codexOutputs: [String: CodexSessionOutput],
    renderCodexFences: Bool = true
  ) -> String {
    let lines = markdown.components(separatedBy: .newlines)
    var html: [String] = []
    var index = 0

    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed.isEmpty {
        index += 1
        continue
      }

      if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
        let fence = String(trimmed.prefix(3))
        let info = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var codeLines: [String] = []
        index += 1

        while index < lines.count {
          let candidate = lines[index].trimmingCharacters(in: .whitespaces)
          if candidate.hasPrefix(fence) {
            break
          }
          codeLines.append(lines[index])
          index += 1
        }

        let code = codeLines.joined(separator: "\n")
        if renderCodexFences,
           info.hasPrefix("codex"),
           let block = CodexBlock.extract(from: "\(fence)\(info)\n\(code)\n\(fence)").first {
          html.append(renderCodexBlock(block, output: codexOutputs[block.id]))
        } else {
          html.append(renderCodeBlock(code, language: info))
        }

        index += 1
        continue
      }

      if let heading = headingHTML(for: trimmed) {
        html.append(heading)
        index += 1
        continue
      }

      if isHorizontalRule(trimmed) {
        html.append("<hr>")
        index += 1
        continue
      }

      if isTableStart(lines, at: index) {
        let rendered = renderTable(lines, startingAt: index)
        html.append(rendered.html)
        index = rendered.nextIndex
        continue
      }

      if listMarker(for: trimmed) != nil {
        let rendered = renderList(
          lines,
          startingAt: index,
          codexOutputs: codexOutputs,
          renderCodexFences: renderCodexFences
        )
        html.append(rendered.html)
        index = rendered.nextIndex
        continue
      }

      if trimmed.hasPrefix(">") {
        let rendered = renderBlockquote(lines, startingAt: index)
        html.append(rendered.html)
        index = rendered.nextIndex
        continue
      }

      let rendered = renderParagraph(lines, startingAt: index)
      html.append(rendered.html)
      index = rendered.nextIndex
    }

    return html.joined(separator: "\n")
  }

  private static func renderSlideActions(for blocks: [CodexBlock]) -> String {
    guard blocks.count > 1 else { return "" }
    return
      """
      <div class="slide-actions">
        <button type="button" class="icon-button slide-action-button run-all" aria-label="Run all Codex sessions" title="Run all Codex sessions" onclick="Codeck.runAllCodex()">
          <span class="run-all-icon" aria-hidden="true"></span>
          <span class="visually-hidden">Run all</span>
        </button>
      </div>
      """
  }

  private static func headingHTML(for line: String) -> String? {
    let level = line.prefix(while: { $0 == "#" }).count
    guard (1...6).contains(level), line.dropFirst(level).first == " " else {
      return nil
    }

    let text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
    return "<h\(level)>\(renderInline(text))</h\(level)>"
  }

  private static func isHorizontalRule(_ line: String) -> Bool {
    line == "***" || line == "___"
  }

  private static func isTableStart(_ lines: [String], at index: Int) -> Bool {
    guard index + 1 < lines.count else { return false }
    return lines[index].contains("|") && isTableSeparator(lines[index + 1])
  }

  private static func isTableSeparator(_ line: String) -> Bool {
    let parts = tableCells(in: line)
    guard !parts.isEmpty else { return false }
    return parts.allSatisfy { cell in
      let trimmed = cell.trimmingCharacters(in: .whitespaces)
      return trimmed.count >= 3 && trimmed.allSatisfy { $0 == "-" || $0 == ":" }
    }
  }

  private static func renderTable(_ lines: [String], startingAt index: Int) -> (html: String, nextIndex: Int) {
    let headers = tableCells(in: lines[index])
    var rowIndex = index + 2
    var rows: [[String]] = []

    while rowIndex < lines.count, lines[rowIndex].contains("|") {
      rows.append(tableCells(in: lines[rowIndex]))
      rowIndex += 1
    }

    let thead = headers.map { "<th>\(renderInline($0.trimmingCharacters(in: .whitespaces)))</th>" }.joined()
    let tbody = rows.map { row in
      "<tr>" + row.map { "<td>\(renderInline($0.trimmingCharacters(in: .whitespaces)))</td>" }.joined() + "</tr>"
    }.joined(separator: "\n")

    return (
      """
      <table>
        <thead><tr>\(thead)</tr></thead>
        <tbody>\(tbody)</tbody>
      </table>
      """,
      rowIndex
    )
  }

  private static func tableCells(in line: String) -> [String] {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("|") {
      trimmed.removeFirst()
    }
    if trimmed.hasSuffix("|") {
      trimmed.removeLast()
    }
    return trimmed.components(separatedBy: "|")
  }

  private static func renderList(
    _ lines: [String],
    startingAt index: Int,
    codexOutputs: [String: CodexSessionOutput],
    renderCodexFences: Bool
  ) -> (html: String, nextIndex: Int) {
    guard let firstMarker = listMarker(for: lines[index].trimmingCharacters(in: .whitespaces)) else {
      return ("", index + 1)
    }

    let ordered = firstMarker.kind == .ordered
    var rowIndex = index
    var items: [String] = []

    while rowIndex < lines.count {
      let trimmed = lines[rowIndex].trimmingCharacters(in: .whitespaces)
      guard let marker = listMarker(for: trimmed), marker.kind == firstMarker.kind else {
        break
      }

      var itemLines = [marker.text]
      rowIndex += 1

      while rowIndex < lines.count {
        let continuation = lines[rowIndex].trimmingCharacters(in: .whitespaces)
        if let nextMarker = listMarker(for: continuation), nextMarker.kind == firstMarker.kind {
          break
        }
        if isStrongListBoundary(continuation) {
          break
        }
        itemLines.append(lines[rowIndex])
        rowIndex += 1
      }

      items.append(renderListItem(itemLines, codexOutputs: codexOutputs, renderCodexFences: renderCodexFences))
    }

    let tag = ordered ? "ol" : "ul"
    let startAttribute = firstMarker.start.map { ordered && $0 != 1 ? " start=\"\($0)\"" : "" } ?? ""
    let body = items.map { "<li>\($0)</li>" }.joined(separator: "\n")
    return ("<\(tag)\(startAttribute)>\n\(body)\n</\(tag)>", rowIndex)
  }

  private static func isUnorderedListLine(_ line: String) -> Bool {
    listMarker(for: line)?.kind == .unordered
  }

  private static func isOrderedListLine(_ line: String) -> Bool {
    listMarker(for: line)?.kind == .ordered
  }

  private static func renderListItem(
    _ lines: [String],
    codexOutputs: [String: CodexSessionOutput],
    renderCodexFences: Bool
  ) -> String {
    let markdown = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !markdown.isEmpty else { return "" }
    return renderBlocks(from: markdown, codexOutputs: codexOutputs, renderCodexFences: renderCodexFences)
  }

  private static func isStrongListBoundary(_ trimmedLine: String) -> Bool {
    headingHTML(for: trimmedLine) != nil || isHorizontalRule(trimmedLine)
  }

  private static func listMarker(for line: String) -> ListMarker? {
    if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
      return ListMarker(kind: .unordered, start: nil, text: String(line.dropFirst(2)))
    }

    guard let dot = line.firstIndex(of: ".") else { return nil }
    let prefix = line[..<dot]
    let suffixStart = line.index(after: dot)
    guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber), line[suffixStart...].hasPrefix(" ") else {
      return nil
    }

    let textStart = line.index(after: suffixStart)
    return ListMarker(
      kind: .ordered,
      start: Int(prefix),
      text: String(line[textStart...])
    )
  }

  private static func renderBlockquote(_ lines: [String], startingAt index: Int) -> (html: String, nextIndex: Int) {
    var rowIndex = index
    var quoteLines: [String] = []

    while rowIndex < lines.count {
      let trimmed = lines[rowIndex].trimmingCharacters(in: .whitespaces)
      guard trimmed.hasPrefix(">") else { break }
      quoteLines.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
      rowIndex += 1
    }

    return ("<blockquote>\(renderInline(quoteLines.joined(separator: " ")))</blockquote>", rowIndex)
  }

  private static func renderParagraph(_ lines: [String], startingAt index: Int) -> (html: String, nextIndex: Int) {
    var rowIndex = index
    var paragraph: [String] = []

    while rowIndex < lines.count {
      let trimmed = lines[rowIndex].trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { break }
      guard headingHTML(for: trimmed) == nil else { break }
      guard !trimmed.hasPrefix("```"), !trimmed.hasPrefix("~~~") else { break }
      guard !isTableStart(lines, at: rowIndex) else { break }
      guard !isUnorderedListLine(trimmed), !isOrderedListLine(trimmed), !trimmed.hasPrefix(">") else { break }
      paragraph.append(trimmed)
      rowIndex += 1
    }

    return ("<p>\(renderInline(paragraph.joined(separator: " ")))</p>", rowIndex)
  }

  private static func renderCodeBlock(_ code: String, language: String) -> String {
    let languageIdentifier = SyntaxHighlighter.languageIdentifier(from: language)
    let languageClass = languageIdentifier.map { " class=\"language-\(escapeAttribute($0))\"" } ?? ""
    let highlightedCode = SyntaxHighlighter.html(for: code, language: languageIdentifier)
    return "<pre><code\(languageClass)>\(highlightedCode)</code></pre>"
  }

  private static func renderCodexBlock(_ block: CodexBlock, output: CodexSessionOutput?) -> String {
    let state = output?.state ?? .idle
    let body = CodexSessionOutputFormatter.markdown(from: output)
    let bodyHTML = renderBlocks(from: body, codexOutputs: [:], renderCodexFences: false)
    let isRunning = state == .running
    let action = isRunning ? "stopCodex" : "runCodex"
    let actionTitle = isRunning ? "Stop" : "Run"
    let actionClass = isRunning ? "icon-button codex-action stop" : "icon-button codex-action run"
    let iconClass = isRunning ? "stop-icon" : "play-icon"

    return
      """
      <section class="codex-card state-\(state.rawValue)">
        <div class="codex-card-heading">
          <div class="codex-card-title-group">
            <div class="codex-title">\(renderInline(block.title))</div>
            <div class="codex-status">\(escapeHTML(state.rawValue))</div>
          </div>
          <button type="button" class="\(actionClass)" aria-label="\(actionTitle) Codex session" title="\(actionTitle) Codex session" onclick="Codeck.\(action)('\(escapeJavaScript(block.id))')">
            <span class="\(iconClass)" aria-hidden="true"></span>
            <span class="visually-hidden">\(actionTitle)</span>
          </button>
        </div>
        <div class="codex-label">Prompt</div>
        <pre class="codex-prompt"><code>\(escapeHTML(block.prompt))</code></pre>
        <div class="codex-label">Output</div>
        <div class="codex-output">
          \(bodyHTML)
        </div>
      </section>
      """
  }

  private static func renderInline(_ text: String) -> String {
    var html = escapeHTML(text)
    html = replace(pattern: "`([^`]+)`", in: html) { matches in
      "<code>\(matches[1])</code>"
    }
    html = replace(pattern: "!\\[([^\\]]*)\\]\\(([^\\)]+)\\)", in: html) { matches in
      "<img src=\"\(matches[2])\" alt=\"\(matches[1])\">"
    }
    html = replace(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", in: html) { matches in
      "<a href=\"\(matches[2])\">\(matches[1])</a>"
    }
    html = replace(pattern: "~~([^~]+)~~", in: html) { matches in
      "<del>\(matches[1])</del>"
    }
    html = replace(pattern: "\\*\\*([^*]+)\\*\\*", in: html) { matches in
      "<strong>\(matches[1])</strong>"
    }
    html = replace(pattern: "\\*([^*]+)\\*", in: html) { matches in
      "<em>\(matches[1])</em>"
    }
    return html
  }

  private static func replace(
    pattern: String,
    in text: String,
    transform: ([String]) -> String
  ) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return text
    }

    let nsText = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
    var result = text

    for match in matches {
      let groups = (0..<match.numberOfRanges).map { index in
        match.range(at: index).location == NSNotFound ? "" : nsText.substring(with: match.range(at: index))
      }
      if let range = Range(match.range, in: result) {
        result.replaceSubrange(range, with: transform(groups))
      }
    }

    return result
  }

  private static func escapeHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

  private static func escapeAttribute(_ value: String) -> String {
    escapeHTML(value).replacingOccurrences(of: "'", with: "&#39;")
  }

  private static func escapeJavaScript(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "'", with: "\\'")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
  }

  private static let baseCSS =
    """
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      min-height: 100%;
      background: var(--bg);
      color: var(--fg);
      font: 24px/1.45 -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
    }
    body {
      display: flex;
      justify-content: center;
    }
    .slide {
      position: relative;
      width: min(100vw, 1600px);
      min-height: 100vh;
      padding: 88px;
      overflow-wrap: anywhere;
    }
    h1, h2, h3, h4, h5, h6 {
      line-height: 1.08;
      margin: 0 0 0.55em;
      font-weight: 780;
    }
    h1 { font-size: 82px; }
    h2 { font-size: 60px; }
    h3 { font-size: 44px; }
    p, ul, ol, blockquote, table, pre, .codex-card {
      margin: 0 0 1.05em;
    }
    p, li, td, th, blockquote {
      max-width: 76ch;
    }
    a { color: var(--accent); }
    img {
      display: block;
      max-width: 100%;
      max-height: 62vh;
      object-fit: contain;
      margin: 1em 0;
      border-radius: 8px;
    }
    table {
      border-collapse: collapse;
      width: 100%;
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 8px;
      overflow: hidden;
    }
    th, td {
      border-bottom: 1px solid var(--border);
      padding: 0.65em 0.75em;
      text-align: left;
    }
    th {
      color: var(--accent-strong);
      background: var(--panel-strong);
    }
    tr:last-child td { border-bottom: 0; }
    blockquote {
      border-left: 5px solid var(--accent);
      padding: 0.1em 0 0.1em 1em;
      color: var(--muted);
    }
    pre {
      white-space: pre-wrap;
      background: var(--code-bg);
      color: var(--code-fg);
      border-radius: 8px;
      padding: 1em;
      overflow: auto;
      font-size: 0.72em;
    }
    code {
      font-family: "SF Mono", Menlo, Consolas, monospace;
    }
    pre code {
      display: block;
    }
    pre code .syntax-comment {
      color: #8b949e;
      font-style: italic;
    }
    pre code .syntax-keyword {
      color: #ff7b72;
    }
    pre code .syntax-type {
      color: #ffa657;
    }
    pre code .syntax-string {
      color: #a5d6ff;
    }
    pre code .syntax-number,
    pre code .syntax-literal {
      color: #79c0ff;
    }
    pre code .syntax-function {
      color: #d2a8ff;
    }
    pre code .syntax-property,
    pre code .syntax-variable {
      color: #79c0ff;
    }
    pre code .syntax-attribute,
    pre code .syntax-symbol {
      color: #f2cc60;
    }
    pre code .syntax-tag,
    pre code .syntax-section {
      color: #7ee787;
    }
    pre code .syntax-name {
      color: #c9d1d9;
    }
    pre code .syntax-operator,
    pre code .syntax-punctuation {
      color: #ffdf5d;
    }
    pre code .syntax-addition {
      color: #7ee787;
    }
    pre code .syntax-deletion {
      color: #ffa198;
    }
    p code, li code, td code {
      padding: 0.08em 0.28em;
      background: var(--panel-strong);
      border-radius: 5px;
      color: var(--accent-strong);
    }
    hr {
      border: 0;
      height: 1px;
      background: var(--border);
      margin: 1.4em 0;
    }
    button {
      font: inherit;
    }
    .visually-hidden {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    }
    .slide-actions {
      position: fixed;
      top: 22px;
      right: 26px;
      z-index: 10;
    }
    .icon-button {
      appearance: none;
      border: 1px solid var(--border);
      background: var(--accent);
      color: var(--bg);
      cursor: pointer;
      display: inline-grid;
      place-items: center;
      flex: 0 0 auto;
      height: 1.42em;
      width: 1.42em;
      border-radius: 999px;
      padding: 0;
    }
    .icon-button:hover {
      filter: brightness(1.08);
    }
    .codex-action.stop {
      background: transparent;
      color: var(--accent-strong);
    }
    .play-icon {
      display: block;
      width: 0;
      height: 0;
      margin-left: 0.08em;
      border-top: 0.24em solid transparent;
      border-bottom: 0.24em solid transparent;
      border-left: 0.36em solid currentColor;
    }
    .stop-icon {
      display: block;
      width: 0.38em;
      height: 0.38em;
      background: currentColor;
      border-radius: 0.08em;
    }
    .run-all-icon {
      display: block;
      position: relative;
      width: 0.68em;
      height: 0.52em;
      line-height: 0;
      transform: translateX(0.08em);
    }
    .run-all-icon::before,
    .run-all-icon::after {
      content: "";
      position: absolute;
      top: 50%;
      transform: translateY(-50%);
      width: 0;
      height: 0;
      border-top: 0.24em solid transparent;
      border-bottom: 0.24em solid transparent;
      border-left: 0.3em solid currentColor;
    }
    .run-all-icon::before {
      left: 0.05em;
    }
    .run-all-icon::after {
      left: 0.31em;
    }
    .codex-card {
      overflow: hidden;
      border: 1px solid var(--border);
      border-radius: 8px;
      background: var(--panel);
      box-shadow: 0 18px 60px rgba(0, 0, 0, 0.18);
    }
    .codex-card-heading {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 0.7em;
      padding: 0.46em 0.56em 0.46em 0.72em;
      color: var(--accent-strong);
      background: var(--panel-strong);
      border-bottom: 1px solid var(--border);
    }
    .codex-card-title-group {
      align-items: baseline;
      display: flex;
      gap: 0.55em;
      min-width: 0;
    }
    .codex-title {
      color: var(--fg);
      font-size: 0.72em;
      font-weight: 700;
      line-height: 1.18;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .codex-status {
      color: var(--muted);
      flex: 0 0 auto;
      font-size: 0.42em;
      font-weight: 720;
      letter-spacing: 0.05em;
      line-height: 1.1;
      text-transform: uppercase;
    }
    .codex-label {
      margin: 0.85em 0.95em -0.25em;
      color: var(--muted);
      font-size: 0.58em;
      font-weight: 760;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    .codex-prompt {
      margin: 0.75em;
      box-shadow: none;
    }
    .codex-prompt {
      max-height: 13em;
      background: var(--panel-strong);
      color: var(--fg);
    }
    .codex-output {
      margin: 0.75em;
      min-height: 9em;
      padding: 1em;
      overflow: auto;
      background: var(--code-bg);
      color: var(--code-fg);
      border-radius: 8px;
      font-size: 0.72em;
    }
    .codex-output > :last-child {
      margin-bottom: 0;
    }
    .codex-output h1,
    .codex-output h2,
    .codex-output h3,
    .codex-output h4,
    .codex-output h5,
    .codex-output h6 {
      margin-bottom: 0.55em;
    }
    .codex-output h1 { font-size: 1.65em; }
    .codex-output h2 { font-size: 1.38em; }
    .codex-output h3 { font-size: 1.15em; }
    .codex-output h4,
    .codex-output h5,
    .codex-output h6 { font-size: 1em; }
    .codex-output p,
    .codex-output ul,
    .codex-output ol,
    .codex-output blockquote,
    .codex-output table,
    .codex-output pre {
      margin: 0 0 0.85em;
    }
    .codex-output p,
    .codex-output li,
    .codex-output td,
    .codex-output th,
    .codex-output blockquote {
      max-width: none;
    }
    .codex-output pre {
      background: rgba(0, 0, 0, 0.18);
      font-size: 0.9em;
    }
    .state-running .codex-status {
      color: var(--accent);
    }
    .state-failed .codex-status {
      color: #ff6b6b;
    }
    @media (max-width: 820px), (max-height: 620px) {
      html, body {
        font-size: 19px;
      }
      .slide {
        padding: 32px;
      }
      h1 { font-size: 46px; }
      h2 { font-size: 36px; }
      h3 { font-size: 28px; }
      pre {
        font-size: 0.68em;
      }
      .codex-card-heading {
        gap: 0.5em;
      }
      .slide-actions {
        top: 12px;
        right: 12px;
      }
    }
    """
}
