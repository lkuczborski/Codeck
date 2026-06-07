@testable import Codeck
import XCTest

final class CodexJSONEventParserTests: XCTestCase {
  func testExtractsAgentMessageDelta() {
    let line = #"{"method":"item/agentMessage/delta","params":{"delta":"Hello **live**"}}"#

    XCTAssertEqual(CodexJSONEventParser.assistantDelta(from: line), "Hello **live**")
  }

  func testExtractsCompletedAppServerAgentMessage() {
    let line = #"{"method":"item/completed","params":{"item":{"type":"agentMessage","text":"Final **answer**"}}}"#

    XCTAssertEqual(CodexJSONEventParser.completedAgentMessage(from: line), "Final **answer**")
  }

  func testExtractsCompletedAgentMessageFromNestedContentArray() {
    let line = #"{"type":"item_completed","item":{"type":"agent_message","content":[{"text":"Nested final"}]}}"#

    XCTAssertEqual(CodexJSONEventParser.completedAgentMessage(from: line), "Nested final")
  }

  func testExtractsCompletedExecAgentMessage() {
    let line = #"{"type":"item.completed","item":{"type":"agent_message","text":"Final exec answer"}}"#

    XCTAssertEqual(CodexJSONEventParser.completedAgentMessage(from: line), "Final exec answer")
  }

  func testExtractsNestedAgentMessageDelta() {
    let line = #"{"payload":{"type":"agent_message_delta","delta":{"text":"Nested live text"}}}"#

    XCTAssertEqual(CodexJSONEventParser.assistantDelta(from: line), "Nested live text")
  }

  func testIgnoresReasoningDelta() {
    let line = #"{"method":"item/reasoning/summaryTextDelta","params":{"delta":"private reasoning"}}"#

    XCTAssertNil(CodexJSONEventParser.assistantDelta(from: line))
  }

  func testExtractsThreadAndTurnResponseIDs() throws {
    let thread = try XCTUnwrap(CodexJSONEventParser.object(from: #"{"id":"session-thread-start","result":{"thread":{"id":"thread-1"}}}"#))
    let turn = try XCTUnwrap(CodexJSONEventParser.object(from: #"{"id":"session-turn-start","result":{"turn":{"id":"turn-1"}}}"#))

    XCTAssertEqual(CodexJSONEventParser.threadID(fromThreadStartResponse: thread, requestID: "session-thread-start"), "thread-1")
    XCTAssertEqual(CodexJSONEventParser.turnID(fromTurnStartResponse: turn, requestID: "session-turn-start"), "turn-1")
  }

  func testExtractsTurnCompletionStatusAndFailureMessage() throws {
    let completed = try XCTUnwrap(CodexJSONEventParser.object(from: #"{"method":"turn/completed","params":{"turn":{"status":"completed"}}}"#))
    let failed = try XCTUnwrap(CodexJSONEventParser
      .object(from: #"{"method":"turn/completed","params":{"turn":{"status":"failed","error":{"message":"Sandbox denied"}}}}"#))

    XCTAssertEqual(CodexJSONEventParser.turnCompletion(from: completed)?.completed, true)
    XCTAssertNil(CodexJSONEventParser.turnCompletion(from: completed)?.message)
    XCTAssertEqual(CodexJSONEventParser.turnCompletion(from: failed)?.completed, false)
    XCTAssertEqual(CodexJSONEventParser.turnCompletion(from: failed)?.message, "Sandbox denied")
  }

  func testExtractsErrorMessagesFromResponsesAndNotifications() throws {
    let responseError = try XCTUnwrap(CodexJSONEventParser.object(from: #"{"id":"request","error":{"description":"Bad request"}}"#))
    let notificationError = try XCTUnwrap(CodexJSONEventParser.object(from: #"{"method":"error","params":{"error":"Tool failed"}}"#))

    XCTAssertEqual(CodexJSONEventParser.errorMessage(from: responseError), "Bad request")
    XCTAssertEqual(CodexJSONEventParser.errorMessage(from: notificationError), "Tool failed")
  }

  func testMatchesNumericResponseIdentifiers() throws {
    let response = try XCTUnwrap(CodexJSONEventParser.object(from: #"{"id":7,"result":{}}"#))

    XCTAssertTrue(CodexJSONEventParser.isResponse(response, requestID: "7"))
    XCTAssertFalse(CodexJSONEventParser.isResponse(response, requestID: "8"))
  }
}
