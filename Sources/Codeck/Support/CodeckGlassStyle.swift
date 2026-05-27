import SwiftUI

extension View {
  @ViewBuilder
  func codeckGlassSurface(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
    if #available(macOS 26.0, *) {
      if interactive {
        self.glassEffect(.regular.tint(.clear).interactive(), in: .rect(cornerRadius: cornerRadius))
      } else {
        self.glassEffect(.regular.tint(.clear), in: .rect(cornerRadius: cornerRadius))
      }
    } else {
      self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
  }

  @ViewBuilder
  func codeckGlassButtonStyle(prominent: Bool = false) -> some View {
    if #available(macOS 26.0, *) {
      if prominent {
        self.buttonStyle(.glassProminent)
      } else {
        self.buttonStyle(.glass)
      }
    } else {
      self.buttonStyle(.bordered)
    }
  }

  @ViewBuilder
  func codeckToolbarIconButtonStyle(prominent: Bool = false) -> some View {
    let buttonWidth: CGFloat = 48
    let buttonHeight: CGFloat = 36
    let button = self
      .labelStyle(.iconOnly)
      .font(.system(size: 19, weight: .medium))
      .imageScale(.large)
      .frame(width: buttonWidth, height: buttonHeight)
      .contentShape(.rect(cornerRadius: 18))
      .controlSize(.large)
      .buttonBorderShape(.capsule)

    if #available(macOS 26.0, *) {
      if prominent {
        button
          .buttonStyle(.glassProminent)
          .frame(width: buttonWidth, height: buttonHeight)
      } else {
        button
          .buttonStyle(.glass)
          .frame(width: buttonWidth, height: buttonHeight)
      }
    } else {
      if prominent {
        button
          .buttonStyle(.borderedProminent)
          .frame(width: buttonWidth, height: buttonHeight)
      } else {
        button
          .buttonStyle(.bordered)
          .frame(width: buttonWidth, height: buttonHeight)
      }
    }
  }
}
