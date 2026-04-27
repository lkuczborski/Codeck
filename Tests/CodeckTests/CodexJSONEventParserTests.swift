import XCTest
@testable import Codeck

final class CodexJSONEventParserTests: XCTestCase {
  func testExtractsAgentMessageDelta() {
    let line = #"{"method":"item/agentMessage/delta","params":{"delta":"Hello **live**"}}"#

    XCTAssertEqual(CodexJSONEventParser.assistantDelta(from: line), "Hello **live**")
  }

  func testExtractsCompletedAppServerAgentMessage() {
    let line = #"{"method":"item/completed","params":{"item":{"type":"agentMessage","text":"Final **answer**"}}}"#

    XCTAssertEqual(CodexJSONEventParser.completedAgentMessage(from: line), "Final **answer**")
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
}
