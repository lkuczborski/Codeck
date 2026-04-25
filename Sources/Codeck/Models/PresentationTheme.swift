import Foundation

enum PresentationTheme: String, CaseIterable, Identifiable {
  case studio
  case midnight
  case chalk
  case solar
  case atelier

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .studio:
      "Studio"
    case .midnight:
      "Midnight"
    case .chalk:
      "Chalk"
    case .solar:
      "Solar"
    case .atelier:
      "Atelier"
    }
  }

  var css: String {
    switch self {
    case .studio:
      """
      :root {
        --bg: #f7f7f2;
        --fg: #202124;
        --muted: #62676d;
        --accent: #126c79;
        --accent-strong: #0d4d57;
        --panel: #ffffff;
        --panel-strong: #ecebe3;
        --border: #d9d7cc;
        --code-bg: #161b22;
        --code-fg: #f0f6fc;
      }
      """
    case .midnight:
      """
      :root {
        --bg: #111318;
        --fg: #f4f0e8;
        --muted: #b8b3a7;
        --accent: #7bdff2;
        --accent-strong: #f7d488;
        --panel: #1b1f27;
        --panel-strong: #252b36;
        --border: #353d4b;
        --code-bg: #080a0f;
        --code-fg: #e8f3ff;
      }
      """
    case .chalk:
      """
      :root {
        --bg: #17332c;
        --fg: #f4f1dc;
        --muted: #c9c2a4;
        --accent: #ffdc7b;
        --accent-strong: #f2a65a;
        --panel: #21473d;
        --panel-strong: #2a594d;
        --border: #5f806f;
        --code-bg: #10251f;
        --code-fg: #f8f2d4;
      }
      """
    case .solar:
      """
      :root {
        --bg: #fbf4dc;
        --fg: #21313c;
        --muted: #67757c;
        --accent: #c4512d;
        --accent-strong: #876318;
        --panel: #fffaf0;
        --panel-strong: #efe3bf;
        --border: #dfc98d;
        --code-bg: #263238;
        --code-fg: #f5f1df;
      }
      """
    case .atelier:
      """
      :root {
        --bg: #241d22;
        --fg: #f6ece3;
        --muted: #c9ada4;
        --accent: #e5989b;
        --accent-strong: #84a59d;
        --panel: #332832;
        --panel-strong: #433342;
        --border: #6d5967;
        --code-bg: #161216;
        --code-fg: #fff6eb;
      }
      """
    }
  }
}
