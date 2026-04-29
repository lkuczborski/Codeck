enum AppAppearanceMode: String, CaseIterable, Identifiable {
  case light
  case dark
  case automatic

  static let storageKey = "appAppearanceMode"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .automatic:
      "Automatic"
    case .light:
      "Light"
    case .dark:
      "Dark"
    }
  }

  var systemImage: String {
    switch self {
    case .automatic:
      "circle.lefthalf.filled"
    case .light:
      "sun.max.fill"
    case .dark:
      "moon.fill"
    }
  }
}
