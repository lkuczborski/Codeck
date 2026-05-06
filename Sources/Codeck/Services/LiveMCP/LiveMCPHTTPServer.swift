import Foundation
import Network

final class LiveMCPHTTPServer: @unchecked Sendable {
  private let port: UInt16
  private let handler: LiveMCPProtocolHandler
  private var listener: NWListener?
  private let queue = DispatchQueue(label: "codeck.live-mcp.http")

  @MainActor
  init(port: UInt16 = LiveMCPSettings.port, handler: LiveMCPProtocolHandler = LiveMCPProtocolHandler()) {
    self.port = port
    self.handler = handler
  }

  func start() throws {
    guard listener == nil else { return }

    let parameters = NWParameters.tcp
    parameters.allowLocalEndpointReuse = true
    parameters.requiredLocalEndpoint = .hostPort(
      host: .ipv4(.loopback),
      port: NWEndpoint.Port(rawValue: port)!
    )
    let listener = try NWListener(using: parameters)
    listener.service = nil
    listener.newConnectionHandler = { [weak self] connection in
      self?.handle(connection)
    }
    listener.stateUpdateHandler = { _ in }
    self.listener = listener
    listener.start(queue: queue)
  }

  func stop() {
    listener?.cancel()
    listener = nil
  }

  private func handle(_ connection: NWConnection) {
    guard case .hostPort(let host, _) = connection.endpoint, host.isLoopback else {
      connection.cancel()
      return
    }

    connection.stateUpdateHandler = { state in
      if case .failed = state {
        connection.cancel()
      }
    }
    connection.start(queue: queue)
    receiveMore(on: connection, buffer: HTTPRequestBuffer())
  }

  private func receiveMore(on connection: NWConnection, buffer: HTTPRequestBuffer) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
      guard let self else {
        connection.cancel()
        return
      }

      if let data {
        buffer.append(data)
      }

      if let request = buffer.request {
        self.respond(to: request, on: connection)
        return
      }

      if isComplete || error != nil {
        connection.cancel()
        return
      }

      self.receiveMore(on: connection, buffer: buffer)
    }
  }

  private func respond(to request: HTTPRequest, on connection: NWConnection) {
    let response: HTTPResponse
    if request.method == "OPTIONS" {
      response = HTTPResponse(status: 204, body: Data())
    } else if request.path != "/mcp" {
      response = jsonErrorResponse(status: 404, code: -32004, message: "Not found.")
    } else if !request.isAllowedOrigin {
      response = jsonErrorResponse(status: 403, code: -32003, message: "Forbidden origin.")
    } else if request.method != "POST" {
      response = jsonErrorResponse(status: 405, code: -32005, message: "Use POST for MCP requests.")
    } else if request.methodHeaderMismatch {
      response = jsonErrorResponse(status: 400, code: -32600, message: "Mcp-Method header does not match the JSON-RPC method.")
    } else if request.nameHeaderMismatch {
      response = jsonErrorResponse(status: 400, code: -32600, message: "Mcp-Name header does not match the JSON-RPC name.")
    } else {
      let body = request.body
      Task { @MainActor in
        let object = self.handler.handleJSONData(body)
        self.send(self.jsonResponse(object), on: connection)
      }
      return
    }

    send(response, on: connection)
  }

  private func send(_ response: HTTPResponse, on connection: NWConnection) {
    let data = response.serialized()
    connection.send(content: data, completion: .contentProcessed { _ in
      connection.cancel()
    })
  }

  private func jsonResponse(_ object: Any?) -> HTTPResponse {
    guard let object else {
      return HTTPResponse(status: 202, body: Data())
    }

    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
      return jsonErrorResponse(status: 500, code: -32603, message: "Could not encode MCP response.")
    }

    return HTTPResponse(status: 200, body: data)
  }

  private func jsonErrorResponse(status: Int, code: Int, message: String) -> HTTPResponse {
    let object: [String: Any] = [
      "jsonrpc": "2.0",
      "id": NSNull(),
      "error": [
        "code": code,
        "message": message
      ]
    ]
    let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    return HTTPResponse(status: status, body: data)
  }
}

private final class HTTPRequestBuffer: @unchecked Sendable {
  private var data = Data()

  var request: HTTPRequest? {
    HTTPRequest(data: data)
  }

  func append(_ newData: Data) {
    data.append(newData)
  }
}

private struct HTTPRequest {
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
    body = data[bodyStart..<(bodyStart + contentLength)]
  }

  var isAllowedOrigin: Bool {
    guard let origin = headers["origin"], !origin.isEmpty else {
      return true
    }
    guard let url = URL(string: origin), let host = url.host(percentEncoded: false)?.lowercased() else {
      return false
    }
    return host == "localhost" || host == "127.0.0.1" || host == "::1"
  }

  var methodHeaderMismatch: Bool {
    guard let declaredMethod = headers["mcp-method"],
          let actualMethod = jsonObject?["method"] as? String else {
      return false
    }
    return declaredMethod != actualMethod
  }

  var nameHeaderMismatch: Bool {
    guard let declaredName = headers["mcp-name"],
          let actualMethod = jsonObject?["method"] as? String else {
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

private struct HTTPResponse {
  let status: Int
  let body: Data

  func serialized() -> Data {
    let headers = [
      "HTTP/1.1 \(status) \(reasonPhrase)",
      "Content-Type: application/json",
      "Content-Length: \(body.count)",
      "MCP-Protocol-Version: \(LiveMCPSettings.protocolVersion)",
      "Access-Control-Allow-Origin: http://127.0.0.1",
      "Access-Control-Allow-Headers: Content-Type, Mcp-Method, Mcp-Name, Mcp-Session-Id, MCP-Protocol-Version",
      "Access-Control-Allow-Methods: POST, OPTIONS",
      "Connection: close",
      "",
      ""
    ].joined(separator: "\r\n")

    var data = Data(headers.utf8)
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

private extension NWEndpoint.Host {
  var isLoopback: Bool {
    switch self {
    case .ipv4(let address):
      return address == .loopback
    case .ipv6(let address):
      return address == .loopback
    case .name(let name, _):
      return name.lowercased() == "localhost"
    @unknown default:
      return false
    }
  }
}
