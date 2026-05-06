import Foundation

enum LiveMCPSettings {
  static let enabledStorageKey = "liveMCPServerEnabled"
  static let port: UInt16 = 49747
  static let protocolVersion = "2025-11-25"

  static var endpointURL: URL {
    URL(string: "http://127.0.0.1:\(port)/mcp")!
  }
}
