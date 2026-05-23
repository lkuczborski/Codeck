import CodeckCore
import SwiftUI

struct DeckAssistantPanelView: View {
  private static let assistantBlockID = "codeck-deck-assistant"

  let deck: PresentationDeck
  let selectedSlideIndex: Int?
  let settings: DeckCodexSettings
  let workingDirectory: URL?
  @ObservedObject var sessions: CodexSessionStore
  let onApply: ([DeckAssistantChange]) -> Void

  @State private var scope: DeckAssistantScope = .currentSlide
  @AppStorage("codeck.deckAssistant.allowsWebResearch") private var allowsWebResearch = false
  @State private var goal = ""
  @State private var proposal: DeckAssistantProposal = .empty
  @State private var selectedChangeIDs: Set<DeckAssistantChange.ID> = []
  @State private var parseError: String?
  @State private var parsedOutputText = ""
  @State private var deckContextCache = DeckAssistantDeckContextCache()

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          requestSection
          statusSection
          proposalSection
        }
        .padding(14)
      }

      Divider()

      footer
    }
    .frame(minWidth: 340, idealWidth: 420, maxWidth: .infinity)
    .background(.thinMaterial)
    .onChange(of: assistantOutput) { _, output in
      handleAssistantOutput(output)
    }
    .onChange(of: deck) { _, _ in
      resetProposalIfIdle()
    }
    .onChange(of: selectedSlideIndex) { _, _ in
      resetProposalIfIdle()
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "sparkles")
        .font(.title3)
        .foregroundStyle(.tint)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text("Deck Assistant")
          .font(.headline)

        Text(selectedSlideLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private var requestSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker("Scope", selection: $scope) {
        ForEach(DeckAssistantScope.allCases) { scope in
          Label(scope.title, systemImage: scope.systemImage)
            .tag(scope)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      TextField(DeckAssistantQuickAction.diagnose.prompt, text: $goal, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...7)
        .disabled(isRunning)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], alignment: .leading, spacing: 8) {
        ForEach(DeckAssistantQuickAction.allCases) { action in
          Button {
            run(action)
          } label: {
            Label(action.title, systemImage: action.systemImage)
              .frame(maxWidth: .infinity)
          }
          .disabled(!canRun(action))
          .help(helpText(for: action))
          .codeckGlassButtonStyle()
        }
      }

      HStack(spacing: 10) {
        Toggle(isOn: $allowsWebResearch) {
          Label("Use web", systemImage: "globe")
        }
        .toggleStyle(.checkbox)
        .disabled(isRunning)
        .help("Allow Codex to use network access for current facts and source citations.")

        Spacer()

        Button {
          runAssistant()
        } label: {
          Label(isRunning ? "Running" : "Ask Codex", systemImage: isRunning ? "hourglass" : "paperplane")
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!canAskCodex)
        .codeckGlassButtonStyle(prominent: true)
      }
    }
    .padding(12)
    .codeckGlassSurface(cornerRadius: 8, interactive: true)
  }

  @ViewBuilder
  private var statusSection: some View {
    if isRunning {
      HStack(spacing: 10) {
        ProgressView()
          .controlSize(.small)

        VStack(alignment: .leading, spacing: 2) {
          Text("Codex is reviewing the deck")
            .font(.subheadline.weight(.semibold))
          Text(allowsWebResearch ? "Deck context and web research are enabled." : "Using deck context only.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button {
          sessions.stop(Self.assistantBlockID)
        } label: {
          Label("Stop", systemImage: "stop.fill")
            .labelStyle(.iconOnly)
        }
        .help("Stop Assistant run")
        .codeckGlassButtonStyle()
      }
      .padding(12)
      .codeckGlassSurface(cornerRadius: 8, interactive: true)
    } else if let parseError {
      VStack(alignment: .leading, spacing: 8) {
        Label("Could not read Codex proposal", systemImage: "exclamationmark.triangle")
          .font(.subheadline.weight(.semibold))

        Text(parseError)
          .font(.caption)
          .foregroundStyle(.secondary)

        DisclosureGroup {
          MarkdownSnippetView(title: "Raw response", markdown: assistantOutput.text)
            .padding(.top, 6)
        } label: {
          Text("Show raw response")
            .font(.caption)
        }
      }
      .padding(12)
      .codeckGlassSurface(cornerRadius: 8, interactive: true)
    }
  }

  @ViewBuilder
  private var proposalSection: some View {
    if proposal.changes.isEmpty {
      emptyProposalState
    } else {
      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Text(proposal.title)
            .font(.subheadline.weight(.semibold))

          Text(proposal.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        VStack(spacing: 10) {
          ForEach(proposal.changes) { change in
            DeckAssistantChangeRow(
              change: change,
              isSelected: Binding(
                get: { selectedChangeIDs.contains(change.id) },
                set: { isSelected in
                  if isSelected {
                    selectedChangeIDs.insert(change.id)
                  } else {
                    selectedChangeIDs.remove(change.id)
                  }
                }
              )
            )
          }
        }
      }
    }
  }

  private var emptyProposalState: some View {
    VStack(spacing: 14) {
      Image(systemName: "sparkle.magnifyingglass")
        .font(.system(size: 42, weight: .regular))
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        Text(proposal.title)
          .font(.title.weight(.bold))

        Text(isRunning ? proposal.summary : "Ask Codex to inspect the slide or deck.")
          .font(.callout.weight(.semibold))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(minHeight: 300)
    .padding(.vertical, 28)
  }

  private var footer: some View {
    HStack(spacing: 10) {
      Text("\(selectedChanges.count) selected")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)

      Spacer()

      Button {
        onApply(selectedChanges)
        proposal = .empty
        selectedChangeIDs = []
      } label: {
        Label("Apply", systemImage: "checkmark")
      }
      .disabled(isRunning || selectedChanges.isEmpty)
      .codeckGlassButtonStyle(prominent: true)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private var assistantOutput: CodexSessionOutput {
    sessions.output(for: Self.assistantBlockID)
  }

  private var isRunning: Bool {
    assistantOutput.state == .running
  }

  private var canRun: Bool {
    !isRunning && !deck.slides.isEmpty
  }

  private var canAskCodex: Bool {
    canRun && !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var selectedChanges: [DeckAssistantChange] {
    proposal.changes.filter { selectedChangeIDs.contains($0.id) }
  }

  private var selectedSlideLabel: String {
    guard let selectedSlideIndex, deck.slides.indices.contains(selectedSlideIndex) else {
      return "\(deck.slides.count) slides"
    }

    return "Slide \(selectedSlideIndex + 1): \(deck.slides[selectedSlideIndex].title)"
  }

  private func run(_ action: DeckAssistantQuickAction) {
    guard canRun(action) else { return }

    goal = action.prompt
    runAssistant(goalOverride: action.prompt)
  }

  private func canRun(_ action: DeckAssistantQuickAction) -> Bool {
    DeckAssistantRunPolicy.canRun(
      action,
      allowsWebResearch: allowsWebResearch,
      isRunning: isRunning
    )
  }

  private func helpText(for action: DeckAssistantQuickAction) -> String {
    if action.requiresWebResearch && !allowsWebResearch {
      return "Turn on Use web to enable \(action.title)."
    }

    return action.prompt
  }

  private func runAssistant(goalOverride: String? = nil) {
    let requestGoal = (goalOverride ?? goal).trimmingCharacters(in: .whitespacesAndNewlines)
    guard canRun, !requestGoal.isEmpty else { return }

    parseError = nil
    parsedOutputText = ""
    proposal = DeckAssistantProposal(
      title: "Codex is drafting",
      summary: "Using a fast pass with compact deck context.",
      changes: []
    )
    selectedChangeIDs = []
    let deckOutline = deckContextCache.outline(for: deck)

    let prompt = DeckAssistantPromptBuilder.prompt(
      goal: requestGoal,
      scope: scope,
      allowsWebResearch: allowsWebResearch,
      deck: deck,
      selectedSlideIndex: selectedSlideIndex,
      deckOutline: deckOutline
    )
    let runSettings = DeckCodexSettings(
      model: settings.model,
      reasoning: .low,
      sandbox: "read-only"
    )

    let block = CodexBlock(
      id: Self.assistantBlockID,
      prompt: prompt,
      model: settings.model,
      reasoning: runSettings.reasoning,
      sandbox: "read-only",
      title: "Deck Assistant"
    )

    sessions.run(
      block,
      settings: runSettings,
      workingDirectory: workingDirectory,
      allowsNetwork: allowsWebResearch,
      keepsSessionAlive: true
    )
  }

  private func handleAssistantOutput(_ output: CodexSessionOutput) {
    guard output.state == .running || output.state == .completed else { return }
    guard output.text != parsedOutputText else { return }
    guard !output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    do {
      let parsedProposal = try DeckAssistantProposalParser.proposal(from: output.text, deck: deck)
      parsedOutputText = output.text
      proposal = parsedProposal
      selectedChangeIDs = Set(parsedProposal.changes.map(\.id))
      parseError = nil
    } catch {
      guard output.state == .completed else { return }
      parsedOutputText = output.text
      proposal = .empty
      selectedChangeIDs = []
      parseError = error.localizedDescription
    }
  }

  private func resetProposalIfIdle() {
    guard !isRunning else { return }
    proposal = .empty
    selectedChangeIDs = []
    parseError = nil
    parsedOutputText = ""
  }
}

private struct DeckAssistantChangeRow: View {
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
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(isSelected ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.16), lineWidth: 1)
    }
  }
}

private struct MarkdownSnippetView: View {
  let title: String
  let markdown: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)

      ScrollView(.horizontal) {
        Text(markdown)
          .font(.system(size: 11, design: .monospaced))
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
      }
      .frame(maxHeight: 170)
      .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
  }
}
