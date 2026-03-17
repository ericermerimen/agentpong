// Sources/Shared/HookServer.swift
import Foundation
import Network

/// Local HTTP server that receives Claude Code hook events.
///
/// Architecture:
///   ┌──────────────┐    POST /hook     ┌─────────────────┐
///   │ hook-sender.sh│ ───────────────► │   HookServer     │
///   │  stdin→curl   │                  │ 127.0.0.1:49152  │
///   │               │ ◄─────────────── │   (loopback)     │
///   │  (blocks for  │  HookDecision    │   held conn      │
///   │   permission) │  JSON + exitcode │   for perms      │
///   └──────────────┘                  └─────────────────┘
///
/// For regular events: immediate 200 OK response.
/// For permission events (PreToolUse with permission_mode="ask"):
///   connection is held open until onPermissionRequest callback
///   invokes the respond closure with a HookDecision.
public final class HookServer: @unchecked Sendable {

    private let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.agentpong.hookserver")

    /// Active connection buffers retained until request is fully read.
    /// Keyed by ObjectIdentifier of the NWConnection to allow cleanup.
    private var activeBuffers: [ObjectIdentifier: ConnectionBuffer] = [:]

    public private(set) var isRunning = false
    public private(set) var actualPort: UInt16 = 0

    /// Called for every non-permission event.
    public var onEvent: ((HookEvent) -> Void)?

    /// Called for permission events (PreToolUse with permission_mode="ask").
    /// The closure must be invoked with a HookDecision to unblock the hook script.
    public var onPermissionRequest: ((HookEvent, @escaping (HookDecision) -> Void) -> Void)?

    public init(port: UInt16 = 49152) {
        self.port = port
    }

    public func start() throws {
        let params = NWParameters.tcp
        let p = port == 0 ? NWEndpoint.Port.any : NWEndpoint.Port(rawValue: port)!
        listener = try NWListener(using: params, on: p)

        // SECURITY: Bind to loopback only. Without this, NWListener
        // defaults to 0.0.0.0 which exposes the server to the local network.
        // Note: For port 0 (auto-assign, used in tests), we skip the endpoint
        // constraint because requiredLocalEndpoint can interfere with port
        // assignment. The production default (49152) always gets the constraint.
        if port != 0 {
            listener?.parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: .ipv4(.loopback),
                port: NWEndpoint.Port(rawValue: port)!
            )
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                if let port = self?.listener?.port?.rawValue {
                    self?.actualPort = port
                }
            case .failed:
                self?.isRunning = false
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)

        // Wait briefly for listener to be ready
        for _ in 0..<20 {
            if isRunning { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        activeBuffers.removeAll()
        isRunning = false
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        // Use a buffered reader to accumulate TCP data until we have the
        // complete HTTP request (headers + full body per Content-Length).
        // A single receive() call is NOT reliable -- TCP can fragment data
        // across multiple packets, especially under load.
        let buffer = ConnectionBuffer(connection: connection)
        let key = ObjectIdentifier(connection)
        activeBuffers[key] = buffer

        buffer.readHTTPRequest { [weak self] result in
            guard let self else {
                connection.cancel()
                return
            }
            // Buffer is no longer needed after request is read
            self.activeBuffers.removeValue(forKey: key)

            switch result {
            case .success(let data):
                self.processHTTPRequest(data: data, connection: connection)
            case .failure:
                self.sendHTTPResponse(connection: connection, status: 400, body: "{\"error\":\"invalid request\"}")
            }
        }
    }

    private func processHTTPRequest(data: Data, connection: NWConnection) {
        // Parse HTTP request to extract JSON body
        guard let request = String(data: data, encoding: .utf8) else {
            sendHTTPResponse(connection: connection, status: 400, body: "{\"error\":\"invalid request\"}")
            return
        }

        // Find JSON body (after the blank line in HTTP request)
        guard let bodyRange = request.range(of: "\r\n\r\n") ?? request.range(of: "\n\n") else {
            sendHTTPResponse(connection: connection, status: 400, body: "{\"error\":\"no body\"}")
            return
        }

        let bodyString = String(request[bodyRange.upperBound...])
        guard let bodyData = bodyString.data(using: .utf8),
              let event = try? JSONDecoder.hookDecoder.decode(HookEvent.self, from: bodyData) else {
            sendHTTPResponse(connection: connection, status: 400, body: "{\"error\":\"invalid json\"}")
            return
        }

        // Permission request: hold the connection open
        if event.isPermissionEvent {
            DispatchQueue.main.async { [weak self] in
                self?.onPermissionRequest?(event) { decision in
                    let responseData = (try? JSONEncoder().encode(decision)) ?? Data()
                    let body = String(data: responseData, encoding: .utf8) ?? "{}"
                    // Exit code 2 = block. We encode this in a header the
                    // hook-sender.sh reads to set the correct exit code.
                    let exitCode = decision.decision == "block" ? 2 : 0
                    self?.sendHTTPResponse(
                        connection: connection,
                        status: 200,
                        body: body,
                        headers: ["X-Hook-Exit-Code: \(exitCode)"]
                    )
                }
            }
            return
        }

        // Regular event: process and respond immediately
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
        sendHTTPResponse(connection: connection, status: 200, body: "{\"ok\":true}")
    }

    private func sendHTTPResponse(connection: NWConnection, status: Int, body: String, headers: [String] = []) {
        let statusText = status == 200 ? "OK" : "Bad Request"
        let extraHeaders = headers.map { "\($0)\r\n" }.joined()
        // NOTE: HTTP headers must start at column 0 (no leading whitespace).
        // Use string concatenation, NOT a multiline string literal (which adds indentation).
        let response = "HTTP/1.1 \(status) \(statusText)\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(body.utf8.count)\r\n"
            + extraHeaders
            + "Connection: close\r\n"
            + "\r\n"
            + body
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

// MARK: - Buffered TCP Reader

/// Accumulates data from an NWConnection and parses HTTP Content-Length
/// to determine when the full request (headers + body) has been received.
///
/// TCP delivers data as a stream -- a single receive() call may return
/// partial headers, partial body, or even multiple requests. This buffer
/// handles the common case: one HTTP request per connection, reading until
/// we have Content-Length bytes of body after the header terminator.
private final class ConnectionBuffer {
    private let connection: NWConnection
    private var accumulated = Data()

    /// Max total request size to prevent memory abuse (1 MB).
    private static let maxRequestSize = 1_048_576

    init(connection: NWConnection) {
        self.connection = connection
    }

    /// Read from the connection until a complete HTTP request is available.
    /// Calls completion with the full request data (headers + body).
    func readHTTPRequest(completion: @escaping (Result<Data, Error>) -> Void) {
        readChunk(completion: completion)
    }

    private func readChunk(completion: @escaping (Result<Data, Error>) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [self] data, _, isComplete, error in
            if let error {
                completion(.failure(error))
                return
            }

            if let data {
                self.accumulated.append(data)
            }

            // Safety: reject oversized requests
            if self.accumulated.count > ConnectionBuffer.maxRequestSize {
                completion(.failure(BufferError.requestTooLarge))
                return
            }

            // Check if we have a complete HTTP request
            if self.isRequestComplete() {
                completion(.success(self.accumulated))
                return
            }

            // If the connection closed before we got the full request,
            // deliver what we have (curl may close after sending).
            if isComplete {
                if self.accumulated.isEmpty {
                    completion(.failure(BufferError.connectionClosed))
                } else {
                    completion(.success(self.accumulated))
                }
                return
            }

            // Need more data -- keep reading
            self.readChunk(completion: completion)
        }
    }

    /// Determines if accumulated data contains a complete HTTP request.
    /// Looks for the header terminator (\r\n\r\n), then checks Content-Length
    /// to see if we have the full body.
    private func isRequestComplete() -> Bool {
        guard let str = String(data: accumulated, encoding: .utf8) else { return false }

        // Find the end of headers
        let headerEnd: Range<String.Index>?
        if let crlfEnd = str.range(of: "\r\n\r\n") {
            headerEnd = crlfEnd
        } else if let lfEnd = str.range(of: "\n\n") {
            headerEnd = lfEnd
        } else {
            // Haven't received full headers yet
            return false
        }

        guard let end = headerEnd else { return false }

        let headersStr = String(str[str.startIndex..<end.lowerBound])
        let bodyStart = end.upperBound

        // Parse Content-Length from headers
        let contentLength = parseContentLength(from: headersStr)

        if contentLength == 0 {
            // No body expected -- headers alone are the complete request
            return true
        }

        // Check if we have enough body bytes
        let bodyReceived = str[bodyStart...].utf8.count
        return bodyReceived >= contentLength
    }

    /// Extract Content-Length value from raw HTTP headers string.
    private func parseContentLength(from headers: String) -> Int {
        let lineBreak = headers.contains("\r\n") ? "\r\n" : "\n"
        for line in headers.components(separatedBy: lineBreak) {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                return Int(value) ?? 0
            }
        }
        return 0
    }

    private enum BufferError: Error {
        case requestTooLarge
        case connectionClosed
    }
}
