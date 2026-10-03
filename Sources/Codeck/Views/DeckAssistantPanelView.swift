import CodeckCore
import CodeckRuntime
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
    @State private var activeRunDeck: PresentationDeck?
    @State private var activeRunFingerprint: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            requestSection
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            Divider()

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        statusSection
                        proposalSection
                            .frame(
                                maxHeight: proposal.changes.isEmpty ? .infinity : nil,
                                alignment: proposal.changes.isEmpty ? .center : .top
                            )
                    }
                    .padding(12)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
            }

            if !proposal.changes.isEmpty {
                Divider()
                footer
            }
        }
        .frame(minWidth: 340, idealWidth: 420, maxWidth: .infinity)
        .codeckWorkspaceBackground()
        .onChange(of: assistantOutput) { _, output in
            handleAssistantOutput(output)
        }
        .onChange(of: deck) { _, _ in
            handleDeckChange()
        }
        .onChange(of: selectedSlideIndex) { _, _ in
            resetProposalIfIdle()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Label("Deck Assistant", systemImage: "sparkles")
                    .font(.headline)

                Spacer(minLength: 8)

                Picker("Scope", selection: $scope) {
                    ForEach(DeckAssistantScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .codeckNativeNavigationPickerStyle()
                .labelsHidden()
                .controlSize(.regular)
                .buttonBorderShape(.capsule)
                .fixedSize()
                .disabled(isRunning)
            }

            Text(selectedSlideLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DeckAssistantComposer(
                goal: $goal,
                allowsWebResearch: $allowsWebResearch,
                isRunning: isRunning,
                canSend: canAskCodex,
                onSend: { runAssistant() },
                onStop: { sessions.stop(Self.assistantBlockID) }
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(DeckAssistantQuickAction.allCases) { action in
                        quickActionButton(action)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(DeckAssistantQuickAction.allCases.prefix(3)) { action in
                            quickActionButton(action)
                        }
                    }

                    HStack(spacing: 6) {
                        ForEach(DeckAssistantQuickAction.allCases.suffix(2)) { action in
                            quickActionButton(action)
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func quickActionButton(_ action: DeckAssistantQuickAction) -> some View {
        Button {
            run(action)
        } label: {
            Label(action.title, systemImage: action.systemImage)
        }
        .controlSize(.small)
        .buttonBorderShape(.capsule)
        .codeckNativeButtonStyle()
        .disabled(!canRun(action))
        .help(helpText(for: action))
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

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
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
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var proposalSection: some View {
        if proposal.changes.isEmpty {
            emptyProposalState
                .frame(maxHeight: .infinity, alignment: .center)
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
        ContentUnavailableView {
            Label(proposal.title, systemImage: "sparkle.magnifyingglass")
        } description: {
            Text(isRunning ? proposal.summary : "Ask Codex to inspect the slide or deck.")
        }
        .frame(maxWidth: .infinity)
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
            .controlSize(.small)
            .codeckNativeButtonStyle(prominent: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        if action.requiresWebResearch, !allowsWebResearch {
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
            summary: "Using the selected deck context.",
            changes: []
        )
        selectedChangeIDs = []
        let runDeck = deck
        let runDeckFingerprint = DeckAssistantDeckContextCache.fingerprint(for: runDeck)
        activeRunDeck = runDeck
        activeRunFingerprint = runDeckFingerprint

        let deckOutline = deckContextCache.outline(for: runDeck)

        let prompt = DeckAssistantPromptBuilder.prompt(
            goal: requestGoal,
            scope: scope,
            allowsWebResearch: allowsWebResearch,
            deck: runDeck,
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
        guard let activeRunDeck, let activeRunFingerprint else { return }

        guard DeckAssistantDeckContextCache.fingerprint(for: deck) == activeRunFingerprint else {
            invalidateActiveRunDueToDeckChange()
            return
        }

        do {
            let parsedProposal = try DeckAssistantProposalParser.proposal(from: output.text, deck: activeRunDeck)
            parsedOutputText = output.text
            proposal = parsedProposal
            selectedChangeIDs = Set(parsedProposal.changes.map(\.id))
            parseError = nil
            if output.state == .completed {
                self.activeRunDeck = nil
                self.activeRunFingerprint = nil
            }
        } catch {
            guard output.state == .completed else { return }
            parsedOutputText = output.text
            proposal = .empty
            selectedChangeIDs = []
            parseError = error.localizedDescription
            self.activeRunDeck = nil
            self.activeRunFingerprint = nil
        }
    }

    private func handleDeckChange() {
        guard isRunning else {
            resetProposalIfIdle()
            return
        }

        guard let activeRunFingerprint else { return }
        guard DeckAssistantDeckContextCache.fingerprint(for: deck) != activeRunFingerprint else { return }
        invalidateActiveRunDueToDeckChange()
    }

    private func invalidateActiveRunDueToDeckChange() {
        activeRunDeck = nil
        activeRunFingerprint = nil
        proposal = .empty
        selectedChangeIDs = []
        parsedOutputText = ""
        parseError = "The deck changed while Codex was reviewing it. Run Assistant again to use the latest slides."
        sessions.stop(Self.assistantBlockID)
    }

    private func resetProposalIfIdle() {
        guard !isRunning else { return }
        proposal = .empty
        selectedChangeIDs = []
        parseError = nil
        parsedOutputText = ""
        activeRunDeck = nil
        activeRunFingerprint = nil
    }
}
