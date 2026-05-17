import XCTest
@testable import CodeckCore
@testable import Codeck

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
              ["reasoningEffort": "ultra"]
            ],
            "defaultReasoningEffort": "ultra"
          ]
        ]
      ]
    ]

    let models = CodexModelListClient.models(from: object)

    XCTAssertEqual(models?.count, 1)
    XCTAssertEqual(models?.first?.id, "gpt-next")
    XCTAssertEqual(models?.first?.displayName, "GPT Next")
    XCTAssertEqual(models?.first?.supportedReasoningEfforts.map(\.rawValue), ["low", "medium", "ultra"])
    XCTAssertEqual(models?.first?.defaultReasoningEffort.rawValue, "ultra")
    XCTAssertEqual(models?.first?.isDefault, true)
  }

  func testIgnoresUnrelatedResponses() {
    let object: [String: Any] = [
      "id": "another-request",
      "result": [
        "models": [
          [
            "id": "gpt-next"
          ]
        ]
      ]
    ]

    XCTAssertNil(CodexModelListClient.models(from: object))
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
