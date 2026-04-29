import SwiftUI

struct AppAppearanceSelector: View {
  @Binding var selection: AppAppearanceMode

  var body: some View {
    HStack(spacing: 2) {
      ForEach(AppAppearanceMode.allCases) { mode in
        Button {
          selection = mode
        } label: {
          Label(mode.title, systemImage: mode.systemImage)
            .labelStyle(.iconOnly)
            .font(.system(size: 14, weight: .semibold))
            .imageScale(.medium)
            .frame(width: 30, height: 28)
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selection == mode ? Color.accentColor : Color.secondary)
        .background(
          selection == mode ? Color.accentColor.opacity(0.2) : Color.clear,
          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(selection == mode ? Color.accentColor.opacity(0.62) : Color.clear, lineWidth: 1)
        }
        .help(mode.title)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(selection == mode ? .isSelected : [])
      }
    }
    .padding(4)
    .codeckGlassSurface(cornerRadius: 12, interactive: true)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Appearance")
  }
}
