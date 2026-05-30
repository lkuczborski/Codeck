import SwiftUI

extension View {
  func codeckGlassSurface(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
    self
      .background(CodeckPalette.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(CodeckPalette.border, lineWidth: interactive ? 1 : 0.75)
      }
  }

  func codeckElevatedSurface(cornerRadius: CGFloat = 8) -> some View {
    self
      .background(CodeckPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(CodeckPalette.border.opacity(0.8), lineWidth: 1)
      }
  }

  func codeckWorkspaceBackground() -> some View {
    self.background(CodeckPalette.workspace)
  }

  func codeckDivider() -> some View {
    self.overlay(CodeckPalette.separator)
  }

  @ViewBuilder
  func codeckControlSurface(isActive: Bool = false, cornerRadius: CGFloat = 7) -> some View {
    if isActive {
      self
        .background(Color.accentColor.opacity(0.22), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.accentColor.opacity(0.66), lineWidth: 1)
        }
    } else {
      self
        .background(CodeckPalette.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(CodeckPalette.border, lineWidth: 1)
        }
    }
  }

  @ViewBuilder
  func codeckGlassButtonStyle(prominent: Bool = false) -> some View {
    self.buttonStyle(CodeckPaletteButtonStyle(prominent: prominent))
  }

  func codeckToolbarIconButtonStyle(prominent: Bool = false) -> some View {
    let buttonWidth: CGFloat = 48
    let buttonHeight: CGFloat = 36
    return self
      .labelStyle(.iconOnly)
      .font(.system(size: 19, weight: .medium))
      .imageScale(.large)
      .frame(width: buttonWidth, height: buttonHeight)
      .contentShape(.rect(cornerRadius: 18))
      .controlSize(.large)
      .buttonBorderShape(.capsule)
      .buttonStyle(.plain)
      .foregroundStyle(prominent ? Color.white : Color.primary)
      .background(
        prominent ? Color.accentColor : CodeckPalette.surface,
        in: Capsule(style: .continuous)
      )
      .overlay {
        Capsule(style: .continuous)
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
