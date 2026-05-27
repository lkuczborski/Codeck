enum DeckAssistantQuickAction: String, CaseIterable, Identifiable, Hashable {
  case diagnose
  case shorten
  case professionalize
  case addResearch
  case addData

  var id: String { rawValue }

  var title: String {
    switch self {
    case .diagnose:
      "Find Gaps"
    case .shorten:
      "Shorten"
    case .professionalize:
      "Polish"
    case .addResearch:
      "Research"
    case .addData:
      "Add Data"
    }
  }

  var systemImage: String {
    switch self {
    case .diagnose:
      "sparkle.magnifyingglass"
    case .shorten:
      "scissors"
    case .professionalize:
      "briefcase"
    case .addResearch:
      "globe"
    case .addData:
      "chart.bar.doc.horizontal"
    }
  }

  var prompt: String {
    switch self {
    case .diagnose:
      "Check what is missing, unclear, unsupported, or too weak for the audience. Propose concrete slide edits."
    case .shorten:
      "Make this tighter and easier to present. Remove filler, reduce cognitive load, and keep the strongest message."
    case .professionalize:
      "Make the presentation more professional, precise, and executive-ready without making it bland."
    case .addResearch:
      "Improve the presentation with relevant current context and cite trustworthy sources when you use external facts."
    case .addData:
      "Add useful data, benchmarks, comparisons, or evidence that would strengthen the argument. Cite sources when external facts are used."
    }
  }

  var requiresWebResearch: Bool {
    switch self {
    case .addResearch, .addData:
      true
    case .diagnose, .shorten, .professionalize:
      false
    }
  }
}
