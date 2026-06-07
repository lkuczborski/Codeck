import CodeckCore
import SwiftUI

struct MarkdownSnippetView: View {
  let title: String
  let markdown: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(markdown)
        .font(.system(size: 11, design: .monospaced))
        .textSelection(.enabled)
        .multilineTextAlignment(.leading)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(8)
        .background(CodeckPalette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
