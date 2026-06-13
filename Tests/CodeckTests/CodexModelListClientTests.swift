@testable import Codeck
@testable import CodeckCore
import XCTest

final class CodexModelListClientTests: XCTestCase {
    func testModelListProcessUsesSandboxedTemporaryDirectory() {
        let process = CodexModelListClient.makeProcess()
        let arguments = process.arguments ?? []

        XCTAssertEqual(Array(arguments.prefix(5)), ["codex", "--sandbox", "read-only", "--ask-for-approval", "never"])
        XCTAssertEqual(arguments[5], "--cd")
        XCTAssertFalse(arguments[6].isEmpty)
        XCTAssertEqual(process.currentDirectoryURL?.path, CodexSessionRunner.sessionWorkingDirectory(from: nil).path)
        XCTAssertEqual(Array(arguments.suffix(3)), ["app-server", "--listen", "stdio://"])
    }

    func testParsesModelListResponseWithDynamicReasoningValues() {
        let object: [String: Any] = [
            "id": "codeck-model-list",
            "result": [
                "data": [
                    [
                        "id": "gpt-next",
                        "displayName": "GPT Next",
                        "description": "Future frontier model.",
                        "isDefault": true,
                        "supportedReasoningEfforts": [
                            ["reasoningEffort": "low"],
                            ["reasoningEffort": "medium"],
                            ["reasoningEffort": "ultra"],
                        ],
                        "defaultReasoningEffort": "ultra",
                    ],
                ],
            ],
        ]

        let models = CodexModelListClient.models(from: object)

        XCTAssertEqual(models?.count, 1)
        XCTAssertEqual(models?.first?.id, "gpt-next")
        XCTAssertEqual(models?.first?.displayName, "GPT Next")
        XCTAssertEqual(models?.first?.supportedReasoningEfforts.map(\.rawValue), ["low", "medium", "ultra"])
        XCTAssertEqual(models?.first?.defaultReasoningEffort.rawValue, "ultra")
        XCTAssertEqual(models?.first?.isDefault, true)
    }

    func testParsesTopLevelSnakeCaseModelPayloadAndSkipsMalformedEntries() {
        let object: [String: Any] = [
            "id": "42",
            "models": [
                [
                    "model": "gpt-snake",
                    "display_name": "GPT Snake",
                    "description": "Uses snake_case fields.",
                    "is_default": true,
                    "supported_reasoning_efforts": ["low", "high"],
                    "default_reasoning_effort": "high",
                ],
                [
                    "display_name": "Missing identifier",
                ],
            ],
        ]

        let models = CodexModelListClient.models(from: object, requestID: "42")

        XCTAssertEqual(models?.count, 1)
        XCTAssertEqual(models?.first?.id, "gpt-snake")
        XCTAssertEqual(models?.first?.displayName, "GPT Snake")
        XCTAssertEqual(models?.first?.description, "Uses snake_case fields.")
        XCTAssertEqual(models?.first?.supportedReasoningEfforts, [.low, .high])
        XCTAssertEqual(models?.first?.defaultReasoningEffort, .high)
        XCTAssertEqual(models?.first?.isDefault, true)
    }

    func testModelPayloadFallsBackToAllReasoningEffortsAndIDDisplayName() {
        let object: [String: Any] = [
            "id": "codeck-model-list",
            "result": [
                "models": [
                    [
                        "id": "gpt-plain",
                    ],
                ],
            ],
        ]

        let model = CodexModelListClient.models(from: object)?.first

        XCTAssertEqual(model?.id, "gpt-plain")
        XCTAssertEqual(model?.displayName, "gpt-plain")
        XCTAssertEqual(model?.description, "")
        XCTAssertEqual(model?.supportedReasoningEfforts, CodexReasoningEffort.allCases)
        XCTAssertEqual(model?.defaultReasoningEffort, .medium)
        XCTAssertEqual(model?.isDefault, false)
    }

    func testIgnoresUnrelatedResponses() {
        let object: [String: Any] = [
            "id": "another-request",
            "result": [
                "models": [
                    [
                        "id": "gpt-next",
                    ],
                ],
            ],
        ]

        XCTAssertNil(CodexModelListClient.models(from: object))
    }

    func testReturnsNilForEmptyOrMalformedModelPayloads() {
        XCTAssertNil(CodexModelListClient.models(from: ["id": "codeck-model-list", "models": []]))
        XCTAssertNil(CodexModelListClient.models(from: ["id": "codeck-model-list", "models": "not an array"]))
        XCTAssertNil(CodexModelListClient.models(from: ["id": "codeck-model-list", "models": [["displayName": "No ID"]]]))
    }

    @MainActor
    func testCatalogKeepsSavedFutureReasoningForUnknownSavedModel() {
        let catalog = CodexModelCatalogStore()
        let options = catalog.modelOptions(
            including: "gpt-future",
            selectedReasoning: CodexReasoningEffort(rawValue: "ultra")
        )

        XCTAssertEqual(options.first?.id, "gpt-future")
        XCTAssertEqual(options.first?.supportedReasoningEfforts.first?.rawValue, "ultra")
    }
}
