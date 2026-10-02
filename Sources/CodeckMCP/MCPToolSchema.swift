import Foundation

enum MCPToolBehavior {
    case readOnly
    case localChange
    case localReplace
    case codexExecution

    var annotations: [String: Bool] {
        [
            "readOnlyHint": self == .readOnly,
            "destructiveHint": self == .localReplace || self == .codexExecution,
            "openWorldHint": self == .codexExecution,
        ]
    }
}

func tool(_ name: String, _ description: String, behavior: MCPToolBehavior, properties: [String: Any] = [:], required: [String] = []) -> [String: Any] {
    [
        "name": name,
        "description": description,
        "annotations": behavior.annotations,
        "inputSchema": [
            "type": "object",
            "properties": properties,
            "required": required,
        ],
    ]
}

func stringSchema(_ description: String) -> [String: Any] {
    ["type": "string", "description": description]
}

func integerSchema(_ description: String) -> [String: Any] {
    ["type": "integer", "description": description]
}

func booleanSchema(_ description: String) -> [String: Any] {
    ["type": "boolean", "description": description]
}

func arraySchema(items: [String: Any]) -> [String: Any] {
    ["type": "array", "items": items]
}

func enumSchema(_ values: [String]) -> [String: Any] {
    ["type": "string", "enum": values]
}
