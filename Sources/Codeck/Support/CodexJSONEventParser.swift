import Foundation

enum CodexJSONEventParser {
  static func assistantDelta(from line: String) -> String? {
    object(from: line).flatMap(assistantDelta(from:))
  }

  static func assistantDelta(from root: [String: Any]) -> String? {
    if let method = root["method"] as? String {
      guard method == "item/agentMessage/delta" else { return nil }
      return firstString(in: root["params"] ?? root, keyedBy: ["delta", "text", "content"])
    }

    if let payload = root["payload"] as? [String: Any],
       let delta = assistantDelta(from: payload) {
      return delta
    }

    if let message = root["msg"] as? [String: Any],
       let delta = assistantDelta(from: message) {
      return delta
    }

    let type = root["type"] as? String
    guard type == "agent_message_delta" || type == "assistant_message_delta" else {
      return nil
    }

    return firstString(in: root, keyedBy: ["delta", "text", "content"])
  }

  static func completedAgentMessage(from line: String) -> String? {
    object(from: line).flatMap(completedAgentMessage(from:))
  }

  static func completedAgentMessage(from root: [String: Any]) -> String? {
    let item: [String: Any]?

    if let method = root["method"] as? String {
      guard method == "item/completed" || method == "item.completed" else { return nil }
      item = (root["params"] as? [String: Any])?["item"] as? [String: Any]
    } else if let type = root["type"] as? String {
      guard type == "item.completed" || type == "item_completed" else { return nil }
      item = root["item"] as? [String: Any]
    } else {
      item = nil
    }

    guard let item, isAgentMessage(item["type"] as? String) else {
      return nil
    }

    if let text = item["text"] as? String {
      return text
    }

    return firstString(in: item["content"] ?? item, keyedBy: ["text"])
  }

  static func threadID(fromThreadStartResponse root: [String: Any], requestID: String) -> String? {
    guard requestIDMatches(root["id"], requestID: requestID),
          let result = root["result"] as? [String: Any],
          let thread = result["thread"] as? [String: Any] else {
      return nil
    }

    return thread["id"] as? String
  }

  static func turnID(fromTurnStartResponse root: [String: Any], requestID: String) -> String? {
    guard requestIDMatches(root["id"], requestID: requestID),
          let result = root["result"] as? [String: Any],
          let turn = result["turn"] as? [String: Any] else {
      return nil
    }

    return turn["id"] as? String
  }

  static func turnCompletion(from root: [String: Any]) -> (completed: Bool, message: String?)? {
    guard root["method"] as? String == "turn/completed",
          let params = root["params"] as? [String: Any],
          let turn = params["turn"] as? [String: Any],
          let status = turn["status"] as? String else {
      return nil
    }

    let message = firstString(in: turn["error"] ?? turn, keyedBy: ["message", "error"])
    return (status == "completed", message)
  }

  static func errorMessage(from root: [String: Any]) -> String? {
    if let error = root["error"] {
      return firstString(in: error, keyedBy: ["message", "error", "description"]) ?? "\(error)"
    }

    guard root["method"] as? String == "error",
          let params = root["params"] else {
      return nil
    }

    return firstString(in: params, keyedBy: ["message", "error", "description"]) ?? "\(params)"
  }

  static func isResponse(_ root: [String: Any], requestID: String) -> Bool {
    requestIDMatches(root["id"], requestID: requestID)
  }

  static func object(from line: String) -> [String: Any]? {
    guard let data = line.data(using: .utf8) else {
      return nil
    }

    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  }

  private static func isAgentMessage(_ type: String?) -> Bool {
    type == "agentMessage" || type == "agent_message"
  }

  private static func requestIDMatches(_ value: Any?, requestID: String) -> Bool {
    if let string = value as? String {
      return string == requestID
    }

    if let number = value as? NSNumber {
      return number.stringValue == requestID
    }

    return false
  }

  private static func firstString(in value: Any, keyedBy keys: [String]) -> String? {
    if let dictionary = value as? [String: Any] {
      for key in keys {
        if let string = dictionary[key] as? String {
          return string
        }
      }

      for nestedValue in dictionary.values {
        if let string = firstString(in: nestedValue, keyedBy: keys) {
          return string
        }
      }
    }

    if let array = value as? [Any] {
      for nestedValue in array {
        if let string = firstString(in: nestedValue, keyedBy: keys) {
          return string
        }
      }
    }

    return nil
  }
}
