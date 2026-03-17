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
        XCTAssertEqual(event.toolInput?["command"]?.value as? String, "rm -rf /tmp/test")
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
