import CodeckCore
import SwiftUI

struct SidebarSlideRow: View {
  let index: Int
  let slide: Slide

  var body: some View {
    HStack(spacing: 10) {
      Text("\(index)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 24, alignment: .trailing)

      VStack(alignment: .leading, spacing: 2) {
        Text(slide.title)
          .lineLimit(1)

        Text(slide.summary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.vertical, 3)
  }
}
