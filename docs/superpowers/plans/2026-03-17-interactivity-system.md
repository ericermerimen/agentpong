# AgentPong Interactivity System Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace file-based session polling with a local HTTP hook server that receives Claude Code events in real-time and enables bidirectional permission handling from the pixel office UI.

**Architecture:** Local TCP server (Network.framework) listens on **127.0.0.1:49152** (loopback only). Claude Code hooks receive JSON on stdin; the hook-sender.sh reads it and POSTs it directly to the server via `curl -d @-` (no string interpolation, no injection risk). For permission requests (PreToolUse with permission_mode="ask"), the HTTP connection is held open while the user approves/denies from an interactive speech bubble in the SpriteKit scene. This transforms AgentPong from a read-only visualization into a control surface.

**Tech Stack:** Swift, Network.framework (NWListener), SpriteKit, existing AgentPong modules

---

## File Structure

```
Sources/
├── Shared/
│   ├── HookServer.swift          (CREATE) HTTP server, connection mgmt, permission holding
│   ├── HookEvent.swift           (CREATE) Codable model for hook JSON payloads
│   ├── Session.swift             (MODIFY) Add permissionRequest field
│   └── SessionReader.swift       (KEEP)   Retained as fallback, not primary
│
├── SpriteEngine/
│   ├── OfficeScene.swift         (MODIFY) Subscribe to HookServer, replace polling as primary
│   └── Nodes/
│       └── CharacterNode.swift   (MODIFY) Interactive bubbles with approve/deny
│
├── App/
│   └── AgentPongApp.swift        (MODIFY) Start HookServer, hook installer command
│
Scripts/
│   └── hook-sender.sh            (CREATE) Shell script installed by `agentpong setup`
```

**Dependency graph:**
```
HookEvent (pure data, no deps)
    ↓
HookServer (depends on: HookEvent, Session)
    ↓
OfficeScene (depends on: HookServer, CharacterNode, Session)
    ↓
CharacterNode (depends on: Shared/SpriteAssetLoader)
    ↓
AgentPongApp (depends on: HookServer, OfficeScene)
```

---

## Chunk 1: Hook Event Model + HTTP Server

### Task 1: Hook Event Model

**Files:**
- Create: `Sources/Shared/HookEvent.swift`
- Test: `Tests/SharedTests/HookEventTests.swift`

- [ ] **Step 1: Write failing test for HookEvent JSON decoding**

```swift
// Tests/SharedTests/HookEventTests.swift
import XCTest
@testable import Shared

final class HookEventTests: XCTestCase {
    func testDecodeSessionStartEvent() throws {
        // Claude Code sends hook_event_name (not "event") and session_id via stdin JSON
        let json = """
        {
            "hook_event_name": "SessionStart",
            "session_id": "abc-123",
            "cwd": "/Users/dev/project",
            "transcript_path": "/tmp/transcript.jsonl"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.hookDecoder.decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "SessionStart")
        XCTAssertEqual(event.sessionId, "abc-123")
        XCTAssertEqual(event.cwd, "/Users/dev/project")
    }

    func testDecodePreToolUseEvent() throws {
        // tool_input is a JSON object (not a string) in the real API
        let json = """
        {
            "hook_event_name": "PreToolUse",
            "session_id": "abc-123",
            "tool_name": "Bash",
            "tool_input": {"command": "rm -rf /tmp/test"},
            "permission_mode": "ask"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.hookDecoder.decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "PreToolUse")
        XCTAssertEqual(event.toolName, "Bash")
        // tool_input is decoded as [String: AnyCodable] dictionary
        XCTAssertEqual(event.toolInput?["command"] as? String, "rm -rf /tmp/test")
    }

    func testDecodeStopEvent() throws {
        let json = """
        {
            "hook_event_name": "Stop",
            "session_id": "abc-123",
            "reason": "end_turn",
            "transcript_path": "/tmp/transcript.jsonl"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.hookDecoder.decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "Stop")
        XCTAssertEqual(event.reason, "end_turn")
    }

    func testDecodePostToolUseEvent() throws {
        let json = """
        {
            "hook_event_name": "PostToolUse",
            "session_id": "abc-123",
            "tool_name": "Write",
            "tool_result": "File written successfully"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.hookDecoder.decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "PostToolUse")
        XCTAssertEqual(event.toolResult, "File written successfully")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HookEventTests 2>&1 | tail -5`
Expected: FAIL — `HookEvent` not defined

- [ ] **Step 3: Implement HookEvent model**

```swift
// Sources/Shared/HookEvent.swift
import Foundation

/// Represents a JSON payload from a Claude Code hook.
///
/// Claude Code hooks receive a JSON object on stdin with these fields.
/// The hook-sender.sh reads this from stdin and POSTs it to HookServer.
///
/// Events flow:
///   Claude Code stdin → hook-sender.sh → POST JSON → HookServer → HookEvent
///
/// For PreToolUse events, the hook can respond with a decision JSON
/// to block the tool use. The HTTP connection is held open while the
/// user approves/denies from the UI.
///
/// > **Note:** The field names below match the actual Claude Code hook API
/// > (verified against ~/.claude/hooks/ examples and plugin-dev tooling).
/// > Key differences from earlier assumptions:
/// > - `hook_event_name` (not `event`)
/// > - `tool_input` is a JSON object (not a string)
/// > - `reason` (not `stop_reason`) for Stop events
/// > - `permission_mode` (not `requires_permission`) indicates permission state
/// > - No `timestamp` field -- hooks don't include one
public struct HookEvent: Codable, Sendable {
    public let hookEventName: String   // SessionStart, SessionEnd, Stop, PreToolUse, PostToolUse, Notification
    public let sessionId: String
    public var cwd: String?
    public var transcriptPath: String?
    public var permissionMode: String? // "ask", "acceptEdits", etc.
    public var toolName: String?       // PreToolUse/PostToolUse
    public var toolInput: [String: AnyCodable]?  // PreToolUse: JSON object (e.g. {"command":"ls"}, {"file_path":"/tmp/x","content":"..."})
    public var toolResult: String?     // PostToolUse: result text
    public var reason: String?         // Stop: end_turn, interrupt, etc.
    public var notificationType: String? // Notification: permission_prompt, idle_prompt, etc.
    public var userPrompt: String?     // UserPromptSubmit

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionId = "session_id"
        case cwd
        case transcriptPath = "transcript_path"
        case permissionMode = "permission_mode"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolResult = "tool_result"
        case reason
        case notificationType = "notification_type"
        case userPrompt = "user_prompt"
    }

    /// Convenience: is this a PreToolUse event where we should show
    /// an interactive permission bubble?
    public var isPermissionEvent: Bool {
        hookEventName == "PreToolUse" && permissionMode == "ask"
    }

    /// Convenience: human-readable description of tool_input.
    public var toolInputDescription: String {
        guard let input = toolInput else { return "" }
        // For Bash: show the command
        if let cmd = input["command"]?.value as? String { return cmd }
        // For Write/Edit: show the file path
        if let path = input["file_path"]?.value as? String { return path }
        // Fallback: show keys
        return input.keys.joined(separator: ", ")
    }
}

/// Decision response for PreToolUse hooks.
/// Output as JSON to stdout. Claude Code reads this to decide
/// whether to allow or block the tool use.
///
/// Exit code also matters:
///   - exit 0: allow (decision JSON optional)
///   - exit 2: block (decision JSON required for reason)
public struct HookDecision: Codable, Sendable {
    public let decision: String        // "allow" or "block"
    public var reason: String?         // Shown to Claude when blocked

    public init(allow: Bool, reason: String? = nil) {
        self.decision = allow ? "allow" : "block"
        self.reason = reason
    }
}

/// Simple type-erased Codable wrapper for JSON values.
public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let b = try? container.decode(Bool.self) { value = b }
        else { value = "" }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let s = value as? String { try container.encode(s) }
        else if let i = value as? Int { try container.encode(i) }
        else if let d = value as? Double { try container.encode(d) }
        else if let b = value as? Bool { try container.encode(b) }
    }
}

extension JSONDecoder {
    /// Decoder configured for hook JSON payloads.
    public static let hookDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter HookEventTests 2>&1 | tail -10`
Expected: PASS (all 4 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/Shared/HookEvent.swift Tests/SharedTests/HookEventTests.swift
git commit -m "feat: add HookEvent model for Claude Code hook payloads"
```

---

### Task 2: HTTP Hook Server

**Files:**
- Create: `Sources/Shared/HookServer.swift`
- Test: `Tests/SharedTests/HookServerTests.swift`

- [ ] **Step 1: Write failing test for HookServer**

```swift
// Tests/SharedTests/HookServerTests.swift
import XCTest
@testable import Shared

final class HookServerTests: XCTestCase {

    func testServerStartsAndStops() async throws {
        let server = HookServer(port: 0)  // 0 = auto-assign port
        try server.start()
        XCTAssertTrue(server.isRunning)
        XCTAssertGreaterThan(server.actualPort, 0)
        server.stop()
        XCTAssertFalse(server.isRunning)
    }

    func testServerReceivesEvent() async throws {
        let server = HookServer(port: 0)
        try server.start()

        let expectation = XCTestExpectation(description: "event received")
        var receivedEvent: HookEvent?

        server.onEvent = { event in
            receivedEvent = event
            expectation.fulfill()
        }

        // POST a hook event
        let url = URL(string: "http://localhost:\(server.actualPort)/hook")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = """
        {"hook_event_name":"SessionStart","session_id":"test-1","cwd":"/tmp"}
        """.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 200)

        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(receivedEvent?.hookEventName, "SessionStart")
        XCTAssertEqual(receivedEvent?.sessionId, "test-1")

        server.stop()
    }

    func testPermissionRequestHoldsConnection() async throws {
        let server = HookServer(port: 0)
        try server.start()

        let permissionExpectation = XCTestExpectation(description: "permission requested")

        server.onPermissionRequest = { event, respond in
            permissionExpectation.fulfill()
            // Simulate user clicking "allow" after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                respond(HookDecision(allow: true))
            }
        }

        let url = URL(string: "http://localhost:\(server.actualPort)/hook")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // permission_mode: "ask" triggers the permission flow
        request.httpBody = """
        {"hook_event_name":"PreToolUse","session_id":"test-1","tool_name":"Bash","tool_input":{"command":"ls"},"permission_mode":"ask"}
        """.data(using: .utf8)

        // This should block until we respond
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 200)

        // Response should contain our hook decision
        let decision = try JSONDecoder().decode(HookDecision.self, from: data)
        XCTAssertEqual(decision.decision, "allow")

        await fulfillment(of: [permissionExpectation], timeout: 2)
        server.stop()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HookServerTests 2>&1 | tail -5`
Expected: FAIL — `HookServer` not defined

- [ ] **Step 3: Implement HookServer**

```swift
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
        listener?.parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: .ipv4(.loopback),
            port: p
        )

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
        isRunning = false
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        // Read the full HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data else {
                connection.cancel()
                return
            }

            self.processHTTPRequest(data: data, connection: connection)
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
        let extraHeaders = headers.isEmpty ? "" : headers.map { "\($0)\r\n" }.joined()
        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        \(extraHeaders)Connection: close\r
        \r
        \(body)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter HookServerTests 2>&1 | tail -15`
Expected: PASS (all 3 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/Shared/HookServer.swift Tests/SharedTests/HookServerTests.swift
git commit -m "feat: add HTTP hook server with held-connection permission handling"
```

---

## Chunk 2: Hook Installer + Session Integration

### Task 3: Hook Sender Script

**Files:**
- Create: `Scripts/hook-sender.sh`

- [ ] **Step 1: Write the hook sender shell script**

```bash
#!/bin/bash
# hook-sender.sh -- Sends Claude Code hook events to AgentPong's local HTTP server.
# Installed by `agentpong setup` into ~/.agentpong/hooks/
#
# Claude Code hooks receive a JSON object on stdin with fields like:
#   session_id, hook_event_name, tool_name, tool_input (object), cwd, etc.
#
# APPROACH: Read the JSON from stdin and forward it directly to the local
# HTTP server via curl. This avoids JSON injection issues (no string
# interpolation) and stays compatible with any future field additions.
#
# For PreToolUse events with permission_mode="ask", the curl request
# blocks until AgentPong responds with a HookDecision JSON. The response
# is printed to stdout so Claude Code can read the decision.
# The exit code is set based on the X-Hook-Exit-Code header (0=allow, 2=block).

set -euo pipefail

PORT=49152
URL="http://localhost:${PORT}/hook"

# Read the full JSON payload from stdin (Claude Code pipes it in)
INPUT=$(cat)

# Determine if this is a permission event that needs to block
EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // ""')
PERM_MODE=$(echo "$INPUT" | jq -r '.permission_mode // ""')

if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ]; then
  TIMEOUT=300
else
  TIMEOUT=5
fi

# Forward the stdin JSON directly to AgentPong -- no string interpolation,
# no injection risk. curl -d @- reads the body from stdin.
RESPONSE=$(echo "$INPUT" | curl -s --max-time "$TIMEOUT" \
  -X POST \
  -H "Content-Type: application/json" \
  -D /dev/stderr \
  -d @- \
  "$URL" 2>/tmp/agentpong-hook-headers.$$ || true)

# For permission events, output the decision JSON and set exit code
if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ] && [ -n "$RESPONSE" ]; then
  echo "$RESPONSE"
  # Read exit code from response header
  EXIT_CODE=$(grep -i "X-Hook-Exit-Code" /tmp/agentpong-hook-headers.$$ 2>/dev/null | tr -dc '0-9' || echo "0")
  rm -f /tmp/agentpong-hook-headers.$$
  exit "${EXIT_CODE:-0}"
fi

rm -f /tmp/agentpong-hook-headers.$$ 2>/dev/null
exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x Scripts/hook-sender.sh
```

- [ ] **Step 3: Commit**

```bash
git add Scripts/hook-sender.sh
git commit -m "feat: add hook sender script for Claude Code integration"
```

---

### Task 4: Update Setup Command

**Files:**
- Modify: `Sources/App/AgentPongApp.swift` (handleSetup function)

- [ ] **Step 1: Read current handleSetup implementation**

Read the existing `handleSetup()` in AgentPongApp.swift to understand what it currently does.

- [ ] **Step 2: Update handleSetup to install hooks automatically**

Replace the current `handleSetup()` that just prints instructions with one that:
1. Copies `hook-sender.sh` to `~/.agentpong/hooks/`
2. Adds hook entries to `~/.claude/settings.json`
3. Prints confirmation

```swift
private func handleSetup() -> Bool {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let hooksDir = home.appendingPathComponent(".agentpong/hooks")
    let hookScript = hooksDir.appendingPathComponent("hook-sender.sh")

    // Create hooks directory
    try? FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)

    // Write hook-sender.sh
    // NOTE: This reads JSON from stdin (Claude Code's hook API) and forwards
    // it directly to the local HTTP server. No string interpolation = no
    // JSON injection risk. Uses jq to extract fields for timeout logic.
    let scriptContent = """
    #!/bin/bash
    set -euo pipefail
    PORT=49152
    URL="http://localhost:${PORT}/hook"
    INPUT=$(cat)
    EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // ""')
    PERM_MODE=$(echo "$INPUT" | jq -r '.permission_mode // ""')
    if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ]; then
      TIMEOUT=300
    else
      TIMEOUT=5
    fi
    RESPONSE=$(echo "$INPUT" | curl -s --max-time "$TIMEOUT" -X POST -H "Content-Type: application/json" -D /dev/stderr -d @- "$URL" 2>/tmp/agentpong-hook-headers.$$ || true)
    if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ] && [ -n "$RESPONSE" ]; then
      echo "$RESPONSE"
      EXIT_CODE=$(grep -i "X-Hook-Exit-Code" /tmp/agentpong-hook-headers.$$ 2>/dev/null | tr -dc '0-9' || echo "0")
      rm -f /tmp/agentpong-hook-headers.$$
      exit "${EXIT_CODE:-0}"
    fi
    rm -f /tmp/agentpong-hook-headers.$$ 2>/dev/null
    exit 0
    """

    do {
        try scriptContent.write(to: hookScript, atomically: true, encoding: .utf8)
        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: hookScript.path
        )
    } catch {
        print("Error writing hook script: \(error)")
        return true
    }

    // Update Claude settings
    let claudeSettings = home.appendingPathComponent(".claude/settings.json")
    var settings: [String: Any] = [:]
    if let data = try? Data(contentsOf: claudeSettings),
       let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        settings = existing
    }

    let hookPath = hookScript.path
    let hookEvents = [
        "SessionStart", "SessionEnd", "Stop",
        "PreToolUse", "PostToolUse",
        "Notification"
    ]

    var hooks = settings["hooks"] as? [String: Any] ?? [:]
    for event in hookEvents {
        hooks[event] = [
            ["type": "command", "command": hookPath]
        ]
    }
    settings["hooks"] = hooks

    if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: claudeSettings, options: .atomic)
    }

    print("AgentPong hooks installed!")
    print("  Hook script: \(hookPath)")
    print("  Claude settings updated: \(claudeSettings.path)")
    print("  Events: \(hookEvents.joined(separator: ", "))")
    print("\nRestart Claude Code for hooks to take effect.")
    return true
}
```

- [ ] **Step 3: Verify build passes**

Run: `swift build 2>&1 | tail -5`
Expected: Build complete

- [ ] **Step 4: Commit**

```bash
git add Sources/App/AgentPongApp.swift
git commit -m "feat: agentpong setup auto-installs Claude Code hooks"
```

---

### Task 5: Wire HookServer into App Lifecycle

**Files:**
- Modify: `Sources/App/AgentPongApp.swift` (AppDelegate)
- Modify: `Sources/SpriteEngine/OfficeScene.swift`

- [ ] **Step 1: Start HookServer in AppDelegate**

In `AppDelegate.applicationDidFinishLaunching`, add:

```swift
// At the top of AppDelegate class:
private let hookServer = HookServer()

// In applicationDidFinishLaunching, after window setup:
do {
    try hookServer.start()
    NSLog("[AgentPong] Hook server started on port \(hookServer.actualPort)")
} catch {
    NSLog("[AgentPong] Failed to start hook server: \(error)")
}

// Pass hookServer to the OfficeScene
if let scene = skView?.scene as? OfficeScene {
    scene.hookServer = hookServer
}
```

- [ ] **Step 2: Add hookServer property to OfficeScene and subscribe to events**

In OfficeScene, add:

```swift
public var hookServer: HookServer? {
    didSet { subscribeToHookEvents() }
}

private func subscribeToHookEvents() {
    hookServer?.onEvent = { [weak self] event in
        self?.handleHookEvent(event)
    }

    hookServer?.onPermissionRequest = { [weak self] event, respond in
        self?.handlePermissionRequest(event, respond: respond)
    }
}

private func handleHookEvent(_ event: HookEvent) {
    // Convert hook event to session update
    let writer = SessionWriter()
    try? writer.report(
        sessionId: event.sessionId,
        event: event.hookEventName.lowercased(),
        cwd: event.cwd
    )
    // Force immediate refresh instead of waiting for next poll
    refreshSessions()
}

private func handlePermissionRequest(_ event: HookEvent, respond: @escaping (HookDecision) -> Void) {
    // Find or create the character for this session
    let sessionId = event.sessionId

    // Store the pending permission
    pendingPermissions[sessionId] = PendingPermission(
        event: event,
        respond: respond
    )

    // Force refresh to show the character
    refreshSessions()

    // Show interactive permission bubble on the character
    if let character = characters[sessionId] {
        let toolDesc = "\(event.toolName ?? "tool"): \(truncate(event.toolInputDescription, to: 30))"
        character.showPermissionBubble(text: toolDesc) { [weak self] allowed in
            respond(HookDecision(allow: allowed))
            self?.pendingPermissions.removeValue(forKey: sessionId)
            character.removeBubble()
        }
    }
}

private func truncate(_ s: String, to length: Int) -> String {
    s.count > length ? String(s.prefix(length)) + "..." : s
}
```

Add the pending permission storage:

```swift
private struct PendingPermission {
    let event: HookEvent
    let respond: (HookDecision) -> Void
}
private var pendingPermissions: [String: PendingPermission] = [:]
```

- [ ] **Step 3: Verify build passes**

Run: `swift build 2>&1 | tail -5`
Expected: Build complete (CharacterNode.showPermissionBubble will fail — that's Task 6)

- [ ] **Step 4: Commit**

```bash
git add Sources/App/AgentPongApp.swift Sources/SpriteEngine/OfficeScene.swift
git commit -m "feat: wire HookServer into app lifecycle, subscribe to events"
```

---

## Chunk 3: Interactive Permission Bubbles

### Task 6: Interactive Speech Bubbles

**Files:**
- Modify: `Sources/SpriteEngine/Nodes/CharacterNode.swift`

- [ ] **Step 1: Add showPermissionBubble to CharacterNode**

```swift
/// Show an interactive permission bubble with approve/deny.
/// The onDecision closure is called with true (allow) or false (deny).
func showPermissionBubble(text: String, onDecision: @escaping (Bool) -> Void) {
    removeBubble()

    let renderedHeight = spriteCanvasSize * spriteScale
    let bubble = SKNode()
    bubble.name = "permission-bubble"
    bubble.position = CGPoint(x: 0, y: renderedHeight + 16)
    bubble.zPosition = 100

    // Background
    let bgW: CGFloat = 80
    let bgH: CGFloat = 28
    let bg = SKShapeNode(rectOf: CGSize(width: bgW, height: bgH), cornerRadius: 4)
    bg.fillColor = SKColor(white: 0.06, alpha: 0.95)
    bg.strokeColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 0.7)
    bg.lineWidth = 1
    bubble.addChild(bg)

    // Tool description label
    let label = SKLabelNode(fontNamed: "Menlo")
    label.text = text
    label.fontSize = 5
    label.fontColor = SKColor(white: 0.9, alpha: 0.9)
    label.verticalAlignmentMode = .center
    label.position = CGPoint(x: 0, y: 5)
    bubble.addChild(label)

    // Allow button (green)
    let allowBtn = SKShapeNode(rectOf: CGSize(width: 30, height: 10), cornerRadius: 2)
    allowBtn.fillColor = SKColor(red: 0.15, green: 0.5, blue: 0.2, alpha: 1.0)
    allowBtn.strokeColor = .clear
    allowBtn.position = CGPoint(x: -18, y: -7)
    allowBtn.name = "allow-btn"
    bubble.addChild(allowBtn)

    let allowLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    allowLabel.text = "Allow"
    allowLabel.fontSize = 5
    allowLabel.fontColor = .white
    allowLabel.verticalAlignmentMode = .center
    allowLabel.position = CGPoint(x: -18, y: -7)
    bubble.addChild(allowLabel)

    // Deny button (red)
    let denyBtn = SKShapeNode(rectOf: CGSize(width: 30, height: 10), cornerRadius: 2)
    denyBtn.fillColor = SKColor(red: 0.5, green: 0.15, blue: 0.15, alpha: 1.0)
    denyBtn.strokeColor = .clear
    denyBtn.position = CGPoint(x: 18, y: -7)
    denyBtn.name = "deny-btn"
    bubble.addChild(denyBtn)

    let denyLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    denyLabel.text = "Deny"
    denyLabel.fontSize = 5
    denyLabel.fontColor = .white
    denyLabel.verticalAlignmentMode = .center
    denyLabel.position = CGPoint(x: 18, y: -7)
    bubble.addChild(denyLabel)

    // Pulse to draw attention
    let pulse = SKAction.sequence([
        SKAction.scale(to: 1.05, duration: 0.5),
        SKAction.scale(to: 1.0, duration: 0.5),
    ])
    bubble.run(SKAction.repeatForever(pulse))

    addChild(bubble)
    bubbleNode = bubble
    permissionCallback = onDecision
}

/// Stored callback for permission decisions.
private var permissionCallback: ((Bool) -> Void)?

/// Handle click on permission bubble buttons.
func handleClick(at scenePoint: CGPoint) -> Bool {
    guard let bubble = bubbleNode, bubble.name == "permission-bubble" else { return false }

    let localPoint = convert(scenePoint, from: scene!)

    // Check allow button hit area
    let allowArea = CGRect(x: -33, y: bubble.position.y - 14, width: 30, height: 12)
    if allowArea.contains(localPoint) {
        permissionCallback?(true)
        permissionCallback = nil
        removeBubble()
        return true
    }

    // Check deny button hit area
    let denyArea = CGRect(x: 3, y: bubble.position.y - 14, width: 30, height: 12)
    if denyArea.contains(localPoint) {
        permissionCallback?(false)
        permissionCallback = nil
        removeBubble()
        return true
    }

    return false
}
```

- [ ] **Step 2: Wire mouse clicks in OfficeScene**

Update `mouseDown(with:)` in OfficeScene:

```swift
public override func mouseDown(with event: NSEvent) {
    let location = event.location(in: self)

    // Check permission bubbles first (highest priority)
    for (_, character) in characters {
        if character.handleClick(at: location) {
            return
        }
    }

    // Click on cat to scare it
    if let cat = mascot, cat.hitTest(location) {
        cat.scare()
    }
}
```

- [ ] **Step 3: Verify build passes**

Run: `swift build 2>&1 | tail -5`
Expected: Build complete

- [ ] **Step 4: Run all tests**

Run: `swift test 2>&1 | tail -15`
Expected: All tests pass (existing + new)

- [ ] **Step 5: Commit**

```bash
git add Sources/SpriteEngine/Nodes/CharacterNode.swift Sources/SpriteEngine/OfficeScene.swift
git commit -m "feat: interactive permission bubbles with allow/deny buttons"
```

---

## Chunk 4: Integration Test + Polish

### Task 7: Manual Integration Test

- [ ] **Step 1: Build and launch the app**

```bash
swift build -c release
```

- [ ] **Step 2: Install hooks**

```bash
swift run AgentPong setup
```

- [ ] **Step 3: Verify hook server is running**

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"hook_event_name":"SessionStart","session_id":"test-1","cwd":"/tmp/test"}' \
  http://localhost:49152/hook
```

Expected: `{"ok":true}` and a character appears in the office

- [ ] **Step 4: Test permission flow**

```bash
# This should block until you click Allow/Deny in the app
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"hook_event_name":"PreToolUse","session_id":"test-1","tool_name":"Bash","tool_input":{"command":"rm -rf /tmp"},"permission_mode":"ask"}' \
  http://localhost:49152/hook
```

Expected: Character shows permission bubble. Click Allow -> `{"decision":"allow"}`. Click Deny -> `{"decision":"block","reason":"..."}`.

- [ ] **Step 5: Test session end**

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"hook_event_name":"Stop","session_id":"test-1","reason":"end_turn"}' \
  http://localhost:49152/hook
```

Expected: Character walks to door and departs.

- [ ] **Step 6: Commit final state**

```bash
git add -A
git commit -m "feat: complete interactivity system - HTTP hooks + permission handling"
```

---

## NOT in scope

- **Keyboard shortcuts** (Cmd+Enter/Cmd+Esc for approve/deny) -- add after basic click works
- **Session switcher popup** (double-tap Cmd) -- separate feature
- **Notification dashboard** -- separate feature
- **VS Code extension for tab focusing** -- separate feature
- **Interrupt detection** (reading transcript JSONL) -- Masko-style, separate feature
- **Custom mascot marketplace** -- commercial feature, much later
- **Snooze/collapse mechanics** -- polish feature
- **Always-allow rules** -- requires understanding Claude Code's permission model deeper

## What already exists

- `SessionWriter.report()` -- already handles event-to-status mapping. HookServer reuses this for session state updates.
- `CharacterNode.showBubble()` -- existing bubble system. Permission bubbles extend this pattern with clickable buttons.
- `OfficeScene.refreshSessions()` -- existing session refresh. HookServer calls this immediately instead of waiting for poll interval.
- `handleSetup()` -- existing CLI command. We modify it to auto-install instead of printing instructions.
- `handleReport()` -- existing CLI report command. Still works as fallback for non-HTTP hook delivery.

## Failure modes

| Codepath | Failure | Test? | Error handling? | User-visible? |
|---|---|---|---|---|
| HookServer port in use | NWListener fails to bind | Yes (port: 0 avoids) | Logs error, falls back to polling | Silent (polling still works) |
| Hook script can't reach server | curl timeout after 5s | No | Script exits 0 silently | Silent (session updates via polling) |
| Permission response never sent | curl blocks for 300s then times out | No | Hook exits 0 (allow by default) | Claude Code proceeds |
| Malformed JSON from hook | JSONDecoder throws | Yes | Returns 400, logs warning | Silent |
| Multiple simultaneous permissions | Dictionary overwrite | No | Latest permission wins | Previous permission times out |

**Critical gap:** Multiple simultaneous permissions from different sessions. Fix: the `pendingPermissions` dictionary keyed by sessionId already handles this correctly -- each session has its own pending permission.
