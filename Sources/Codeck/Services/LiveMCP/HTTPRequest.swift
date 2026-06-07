import Foundation
import Network

struct HTTPRequest {
  let method: String
  let path: String
  let headers: [String: String]
  let body: Data

  init?(data: Data) {
    guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else {
      return nil
    }

    let headerData = data[..<headerRange.lowerBound]
    guard let headerText = String(data: headerData, encoding: .utf8) else {
      return nil
    }

    let lines = headerText.components(separatedBy: "\r\n")
    guard let requestLine = lines.first else { return nil }
    let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
    guard requestParts.count >= 2 else { return nil }

    var headers: [String: String] = [:]
    for line in lines.dropFirst() {
      let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { continue }
      headers[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
    }

    let contentLength = Int(headers["content-length"] ?? "0") ?? 0
    let bodyStart = headerRange.upperBound
    guard data.count >= bodyStart + contentLength else {
      return nil
    }

    method = requestParts[0].uppercased()
    path = requestParts[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? requestParts[1]
    self.headers = headers
    body = data[bodyStart ..< (bodyStart + contentLength)]
  }

  var allowedCORSOrigin: String? {
    guard let origin = headers["origin"], !origin.isEmpty else {
      return nil
    }
    guard let url = URL(string: origin),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let host = url.host(percentEncoded: false)?.lowercased()
    else {
      return nil
    }
    guard host == "localhost" || host == "127.0.0.1" || host == "::1" else {
      return nil
    }
    return origin
  }

  var isAllowedOrigin: Bool {
    guard headers["origin"] != nil else {
      return true
    }
    return allowedCORSOrigin != nil
  }

  var methodHeaderMismatch: Bool {
    guard let declaredMethod = headers["mcp-method"],
          let actualMethod = jsonObject?["method"] as? String
    else {
      return false
    }
    return declaredMethod != actualMethod
  }

  var nameHeaderMismatch: Bool {
    guard let declaredName = headers["mcp-name"],
          let actualMethod = jsonObject?["method"] as? String
    else {
      return false
    }

    let params = jsonObject?["params"] as? [String: Any]
    switch actualMethod {
    case "tools/call":
      return declaredName != params?["name"] as? String
    case "resources/read":
      return declaredName != params?["uri"] as? String
    case "prompts/get":
      return declaredName != params?["name"] as? String
    default:
      return false
    }
  }

  private var jsonObject: [String: Any]? {
    (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
  }
}
