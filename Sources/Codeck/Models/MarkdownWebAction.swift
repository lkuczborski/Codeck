import Foundation

enum MarkdownWebAction: Hashable {
  case runCodex(String)
  case stopCodex(String)
  case runAllCodex
}
