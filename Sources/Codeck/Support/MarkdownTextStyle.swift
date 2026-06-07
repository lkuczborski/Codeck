import Foundation

enum MarkdownTextStyle: String, CaseIterable, Identifiable, Hashable {
  case bold
  case italic
  case inlineCode
  case strikethrough
  case link

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .bold:
      "Bold"
    case .italic:
      "Italic"
    case .inlineCode:
      "Inline Code"
    case .strikethrough:
      "Strikethrough"
    case .link:
      "Link"
    }
  }

  var help: String {
    switch self {
    case .bold:
      "Bold selected text"
    case .italic:
      "Italicize selected text"
    case .inlineCode:
      "Format selected text as inline code"
    case .strikethrough:
      "Strike through selected text"
    case .link:
      "Turn selected text into a link"
    }
  }

  var marker: String? {
    switch self {
    case .bold:
      "**"
    case .italic:
      "*"
    case .inlineCode:
      "`"
    case .strikethrough:
      "~~"
    case .link:
      nil
    }
  }

  var placeholder: String {
    switch self {
    case .inlineCode:
      "code"
    case .link:
      "Link text"
    default:
      "text"
    }
  }
}
