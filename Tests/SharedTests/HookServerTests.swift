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
