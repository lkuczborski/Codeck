import CodeckCore
import SwiftUI

struct DeckAssistantChangeRow: View {
  let change: DeckAssistantChange
  @Binding var isSelected: Bool
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(isOn: $isSelected) {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(change.title)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)

            Spacer(minLength: 8)

            Text(change.locationLabel)
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          Text(change.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .toggleStyle(.checkbox)

      DisclosureGroup(isExpanded: $isExpanded) {
        VStack(alignment: .leading, spacing: 8) {
          if let beforeMarkdown = change.beforeMarkdown {
            MarkdownSnippetView(title: "Before", markdown: beforeMarkdown)
          }

          MarkdownSnippetView(title: "After", markdown: change.afterMarkdown)
        }
        .padding(.top, 6)
      } label: {
        Label(isExpanded ? "Hide Preview" : "Show Preview", systemImage: "doc.text.magnifyingglass")
          .font(.caption)
      }
    }
    .padding(10)
    .codeckElevatedSurface(cornerRadius: 8)
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(isSelected ? Color.accentColor.opacity(0.55) : CodeckPalette.border, lineWidth: 1)
    }
  }
}
