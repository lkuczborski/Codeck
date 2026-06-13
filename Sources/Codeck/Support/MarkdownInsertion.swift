import Foundation

enum MarkdownInsertion: String, CaseIterable, Identifiable {
    case heading1
    case heading2
    case heading3
    case paragraph
    case bulletedList
    case numberedList
    case blockquote
    case link
    case image
    case codeBlock
    case table
    case horizontalRule
    case codexSession

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .heading1:
            "Heading 1"
        case .heading2:
            "Heading 2"
        case .heading3:
            "Heading 3"
        case .paragraph:
            "Paragraph"
        case .bulletedList:
            "Bulleted List"
        case .numberedList:
            "Numbered List"
        case .blockquote:
            "Quote"
        case .link:
            "Link"
        case .image:
            "Image"
        case .codeBlock:
            "Code Block"
        case .table:
            "Table"
        case .horizontalRule:
            "Divider"
        case .codexSession:
            "Codex Session"
        }
    }

    var systemImage: String {
        switch self {
        case .heading1, .heading2, .heading3:
            "textformat.size"
        case .paragraph:
            "paragraphsign"
        case .bulletedList:
            "list.bullet"
        case .numberedList:
            "list.number"
        case .blockquote:
            "quote.opening"
        case .link:
            "link"
        case .image:
            "photo"
        case .codeBlock:
            "chevron.left.forwardslash.chevron.right"
        case .table:
            "tablecells"
        case .horizontalRule:
            "minus"
        case .codexSession:
            "terminal"
        }
    }

    var isBlock: Bool {
        self != .link
    }

    func template(codexBlockNumber: Int) -> MarkdownInsertionTemplate {
        switch self {
        case .heading1:
            MarkdownInsertionTemplate(text: "# Heading", selectedText: "Heading")
        case .heading2:
            MarkdownInsertionTemplate(text: "## Heading", selectedText: "Heading")
        case .heading3:
            MarkdownInsertionTemplate(text: "### Heading", selectedText: "Heading")
        case .paragraph:
            MarkdownInsertionTemplate(text: "Paragraph text", selectedText: "Paragraph text")
        case .bulletedList:
            MarkdownInsertionTemplate(text: "- First item\n- Second item", selectedText: "First item")
        case .numberedList:
            MarkdownInsertionTemplate(text: "1. First item\n2. Second item", selectedText: "First item")
        case .blockquote:
            MarkdownInsertionTemplate(text: "> Quote text", selectedText: "Quote text")
        case .link:
            MarkdownInsertionTemplate(text: "[Link text](https://example.com)", selectedText: "Link text")
        case .image:
            MarkdownInsertionTemplate(text: "![Alt text](Images/example.png)", selectedText: "Alt text")
        case .codeBlock:
            MarkdownInsertionTemplate(text: "```swift\nlet value = \"Hello\"\n```", selectedText: "let value = \"Hello\"")
        case .table:
            MarkdownInsertionTemplate(
                text: "| Header | Header |\n| --- | --- |\n| Cell | Cell |",
                selectedText: "Header"
            )
        case .horizontalRule:
            MarkdownInsertionTemplate(text: "***", selectedText: nil)
        case .codexSession:
            MarkdownInsertionTemplate(
                text:
                """
                ```codex id=demo-\(codexBlockNumber)
                title: Describe the goal for this prompt

                Explain this concept with one concrete example.
                ```
                """,
                selectedText: "Describe the goal for this prompt"
            )
        }
    }
}
