// Sources/Shared/HookEvent.swift
import Foundation

/// Represents a JSON payload from a Claude Code hook.
///
/// Claude Code hooks receive a JSON object on stdin with these fields.
/// The hook-sender.sh reads this from stdin and POSTs it to HookServer.
///
/// Events flow:
///   Claude Code stdin -> hook-sender.sh -> POST JSON -> HookServer -> HookEvent
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
