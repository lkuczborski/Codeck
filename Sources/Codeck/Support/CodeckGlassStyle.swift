import SwiftUI

extension View {
  func codeckGlassSurface(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
    background(CodeckPalette.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(CodeckPalette.border, lineWidth: interactive ? 1 : 0.75)
      }
  }

  func codeckElevatedSurface(cornerRadius: CGFloat = 8) -> some View {
    background(CodeckPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(CodeckPalette.border.opacity(0.8), lineWidth: 1)
      }
  }

  func codeckWorkspaceBackground() -> some View {
    background(CodeckPalette.workspace)
  }

  func codeckDivider() -> some View {
    overlay(CodeckPalette.separator)
  }

  @ViewBuilder
  func codeckControlSurface(isActive: Bool = false, cornerRadius: CGFloat = 7) -> some View {
    if isActive {
      background(Color.accentColor.opacity(0.22), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.accentColor.opacity(0.66), lineWidth: 1)
        }
    } else {
      background(CodeckPalette.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(CodeckPalette.border, lineWidth: 1)
        }
    }
  }

  func codeckGlassButtonStyle(prominent: Bool = false) -> some View {
    buttonStyle(CodeckPaletteButtonStyle(prominent: prominent))
  }

  func codeckToolbarIconButtonStyle(prominent: Bool = false) -> some View {
    let buttonWidth: CGFloat = 30
    let buttonHeight: CGFloat = 28
    let cornerRadius: CGFloat = 8
    return labelStyle(.iconOnly)
      .font(.system(size: 14, weight: .semibold))
      .imageScale(.medium)
      .frame(width: buttonWidth, height: buttonHeight)
      .contentShape(.rect(cornerRadius: cornerRadius))
      .buttonStyle(.plain)
      .foregroundStyle(prominent ? Color.white : Color.primary)
      .background(
        prominent ? Color.accentColor : CodeckPalette.surface,
        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(prominent ? Color.accentColor.opacity(0.9) : CodeckPalette.border, lineWidth: 1)
      }
      .frame(width: buttonWidth, height: buttonHeight)
  }
}

private struct CodeckPaletteButtonStyle: ButtonStyle {
  let prominent: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.body.weight(.medium))
      .foregroundStyle(prominent ? Color.white : Color.primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(background(for: configuration), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(border(for: configuration), lineWidth: 1)
      }
      .opacity(configuration.isPressed ? 0.86 : 1)
  }

  private func background(for configuration: Configuration) -> Color {
    if prominent {
      return Color.accentColor.opacity(configuration.isPressed ? 0.82 : 1)
    }
    return configuration.isPressed ? CodeckPalette.elevatedSurface : CodeckPalette.surface
  }

  private func border(for configuration: Configuration) -> Color {
    if prominent {
      return Color.accentColor.opacity(configuration.isPressed ? 0.72 : 0.9)
    }
    return CodeckPalette.border
  }
}
