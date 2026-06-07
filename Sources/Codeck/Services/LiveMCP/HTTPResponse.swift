import Foundation
import Network

struct HTTPResponse {
  let status: Int
  let body: Data
  let allowedOrigin: String?

  func serialized() -> Data {
    var headers = [
      "HTTP/1.1 \(status) \(reasonPhrase)",
      "Content-Type: application/json",
      "Content-Length: \(body.count)",
      "MCP-Protocol-Version: \(LiveMCPSettings.protocolVersion)",
    ]
    if let allowedOrigin {
      headers.append("Access-Control-Allow-Origin: \(allowedOrigin)")
    }
    headers.append(contentsOf: [
      "Access-Control-Allow-Headers: Content-Type, Mcp-Method, Mcp-Name, Mcp-Session-Id, MCP-Protocol-Version",
      "Access-Control-Allow-Methods: POST, OPTIONS",
      "Connection: close",
      "",
      "",
    ])

    let headerText = headers.joined(separator: "\r\n")
    var data = Data(headerText.utf8)
    data.append(body)
    return data
  }

  private var reasonPhrase: String {
    switch status {
    case 200:
      "OK"
    case 202:
      "Accepted"
    case 204:
      "No Content"
    case 400:
      "Bad Request"
    case 403:
      "Forbidden"
    case 404:
      "Not Found"
    case 405:
      "Method Not Allowed"
    default:
      "Internal Server Error"
    }
  }
}
