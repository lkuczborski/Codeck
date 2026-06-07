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
    guard case let .hostPort(host, _) = connection.endpoint, host.isLoopback else {
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
        respond(to: request, on: connection)
        return
      }

      if isComplete || error != nil {
        connection.cancel()
        return
      }

      receiveMore(on: connection, buffer: buffer)
    }
  }

  private func respond(to request: HTTPRequest, on connection: NWConnection) {
    let response: HTTPResponse
    let allowedOrigin = request.allowedCORSOrigin

    if request.path != "/mcp" {
      response = jsonErrorResponse(status: 404, code: -32004, message: "Not found.", allowedOrigin: allowedOrigin)
    } else if !request.isAllowedOrigin {
      response = jsonErrorResponse(status: 403, code: -32003, message: "Forbidden origin.")
    } else if request.method == "OPTIONS" {
      response = HTTPResponse(status: 204, body: Data(), allowedOrigin: allowedOrigin)
    } else if request.method != "POST" {
      response = jsonErrorResponse(status: 405, code: -32005, message: "Use POST for MCP requests.", allowedOrigin: allowedOrigin)
    } else if request.methodHeaderMismatch {
      response = jsonErrorResponse(status: 400, code: -32600, message: "Mcp-Method header does not match the JSON-RPC method.", allowedOrigin: allowedOrigin)
    } else if request.nameHeaderMismatch {
      response = jsonErrorResponse(status: 400, code: -32600, message: "Mcp-Name header does not match the JSON-RPC name.", allowedOrigin: allowedOrigin)
    } else {
      let body = request.body
      Task { @MainActor in
        let object = self.handler.handleJSONData(body)
        self.send(self.jsonResponse(object, allowedOrigin: allowedOrigin), on: connection)
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

  private func jsonResponse(_ object: Any?, allowedOrigin: String?) -> HTTPResponse {
    guard let object else {
      return HTTPResponse(status: 202, body: Data(), allowedOrigin: allowedOrigin)
    }

    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    else {
      return jsonErrorResponse(status: 500, code: -32603, message: "Could not encode MCP response.", allowedOrigin: allowedOrigin)
    }

    return HTTPResponse(status: 200, body: data, allowedOrigin: allowedOrigin)
  }

  private func jsonErrorResponse(status: Int, code: Int, message: String, allowedOrigin: String? = nil) -> HTTPResponse {
    let object: [String: Any] = [
      "jsonrpc": "2.0",
      "error": [
        "code": code,
        "message": message,
      ],
    ]
    let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    return HTTPResponse(status: status, body: data, allowedOrigin: allowedOrigin)
  }
}

private extension NWEndpoint.Host {
  var isLoopback: Bool {
    switch self {
    case let .ipv4(address):
      return address == .loopback
    case let .ipv6(address):
      return address == .loopback
    case let .name(name, _):
      return name.lowercased() == "localhost"
    @unknown default:
      return false
    }
  }
}
