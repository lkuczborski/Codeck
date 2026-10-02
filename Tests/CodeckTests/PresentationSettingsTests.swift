@testable import Codeck
@testable import CodeckCore
import XCTest

final class PresentationSettingsTests: XCTestCase {
    func testReasoningEffortDisplayNamesCoverKnownAndFutureValues() {
        XCTAssertEqual(CodexReasoningEffort.low.displayName, "Light")
        XCTAssertEqual(CodexReasoningEffort.medium.displayName, "Medium")
        XCTAssertEqual(CodexReasoningEffort.high.displayName, "High")
        XCTAssertEqual(CodexReasoningEffort.xhigh.displayName, "Extra High")
        XCTAssertEqual(CodexReasoningEffort(rawValue: "very-high").displayName, "Very High")
    }

    func testNormalizedModelIDTrimsAndFallsBackForEmptyValues() {
        XCTAssertEqual(CodexModelOption.normalizedModelID("  gpt-custom  "), "gpt-custom")
        XCTAssertEqual(CodexModelOption.normalizedModelID("   "), CodexModelOption.defaultModelID)
        XCTAssertEqual(CodexModelOption.normalizedModelID(nil), CodexModelOption.defaultModelID)
    }

    func testNormalizedReasoningUsesMediumWhenSavedReasoningIsUnsupported() {
        let option = CodexModelOption(
            id: "custom",
            displayName: "Custom",
            description: "",
            supportedReasoningEfforts: [.low, .medium],
            defaultReasoningEffort: .low,
            isDefault: false
        )

        let normalized = CodexModelOption.normalizedReasoning(.xhigh, for: "custom", in: [option])

        XCTAssertEqual(normalized, .medium)
    }

    func testNormalizedReasoningFallsBackToModelDefaultWhenMediumIsUnavailable() {
        let option = CodexModelOption(
            id: "fast-only",
            displayName: "Fast Only",
            description: "",
            supportedReasoningEfforts: [.low],
            defaultReasoningEffort: .low,
            isDefault: false
        )

        let normalized = CodexModelOption.normalizedReasoning(.xhigh, for: "fast-only", in: [option])

        XCTAssertEqual(normalized, .low)
    }

    func testNormalizedReasoningPreservesFutureReasoningForUnknownModel() {
        let futureReasoning = CodexReasoningEffort(rawValue: "ultra")

        let normalized = CodexModelOption.normalizedReasoning(futureReasoning, for: "future-model", in: [])

        XCTAssertEqual(normalized, futureReasoning)
    }

    func testPreferredDefaultDoesNotNormalizeExplicitReasoningOrNeedAStaticCatalog() {
        XCTAssertEqual(CodexModelOption.defaultModelID, "gpt-6.1-sol")
        XCTAssertEqual(CodexModelOption.normalizedReasoning(nil, for: "gpt-6.1-sol"), .low)
        XCTAssertEqual(CodexModelOption.normalizedReasoning(.medium, for: "gpt-6.1-sol"), .medium)
        XCTAssertEqual(CodexModelOption.normalizedReasoning(.init(rawValue: "future"), for: "future-model"), .init(rawValue: "future"))
    }

    @MainActor
    func testCatalogPrependsSavedModelWhenLiveCatalogDoesNotContainIt() throws {
        let catalog = try CodexModelCatalogStore(defaults: XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))
        let options = catalog.modelOptions(
            including: "saved-model",
            selectedReasoning: CodexReasoningEffort(rawValue: "ultra")
        )

        XCTAssertEqual(options.first?.id, "saved-model")
        XCTAssertEqual(options.first?.displayName, "saved-model")
        XCTAssertEqual(options.first?.description, "Saved model from this deck.")
        XCTAssertEqual(options.first?.supportedReasoningEfforts.first?.rawValue, "ultra")
        XCTAssertEqual(options.count, 1)
    }

    @MainActor
    func testCatalogDoesNotDuplicateKnownSelectedModel() throws {
        let catalog = try CodexModelCatalogStore(defaults: XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))
        let options = catalog.modelOptions(including: CodexModelOption.defaultModelID)

        XCTAssertEqual(options.first?.id, CodexModelOption.defaultModelID)
        XCTAssertEqual(options.count(where: { $0.id == CodexModelOption.defaultModelID }), 1)
    }
}
