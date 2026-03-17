import Testing
@testable import Shared
import Foundation

@Suite("Session Model")
struct SessionModelTests {

    @Test("Zone mapping for each status")
    func zoneMapping() {
        #expect(Session(id: "1", status: .running).zone == .desk)
        #expect(Session(id: "2", status: .idle).zone == .lounge)
        #expect(Session(id: "3", status: .error).zone == .debugStation)
        #expect(Session(id: "4", status: .done).zone == .door)
        #expect(Session(id: "5", status: .needsInput).zone == .lounge)
    }

    @Test("Visibility based on status")
    func visibility() {
        #expect(Session(id: "1", status: .running).isVisible == true)
        #expect(Session(id: "2", status: .idle).isVisible == true)
        #expect(Session(id: "3", status: .error).isVisible == true)
        #expect(Session(id: "4", status: .needsInput).isVisible == true)
        #expect(Session(id: "5", status: .done).isVisible == false)
        #expect(Session(id: "6", status: .unavailable).isVisible == false)
    }

    @Test("Display name priority: name > cwd basename > id prefix")
    func displayName() {
        #expect(Session(id: "abc", name: "my-project").displayName == "my-project")
        #expect(Session(id: "abc", cwd: "/Users/me/projects/cool-app").displayName == "cool-app")
        #expect(Session(id: "abcdef12-3456-7890").displayName == "abcdef12")
    }

    @Test("JSON round-trip encoding/decoding")
    func codable() throws {
        let session = Session(
            id: "test-123",
            status: .running,
            name: "my-project",
            cwd: "/tmp/test",
            contextPercent: 42.5,
            cost: 0.15,
            lastUpdated: Date(timeIntervalSince1970: 1710500000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Session.self, from: data)

        #expect(decoded.id == "test-123")
        #expect(decoded.status == .running)
        #expect(decoded.name == "my-project")
        #expect(decoded.contextPercent == 42.5)
    }
}

@Suite("Session Writer & Reader")
struct SessionIOTests {

    @Test("Write then read a session")
    func writeAndRead() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentpong-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let writer = SessionWriter(sessionsDir: tmpDir)
        let reader = SessionReader(primaryDir: tmpDir, agentPingDir: nil)

        try writer.report(sessionId: "session-1", event: "start", cwd: "/tmp/project")

        let sessions = reader.readAll()
        #expect(sessions.count == 1)
        #expect(sessions[0].id == "session-1")
        #expect(sessions[0].status == .running)
        #expect(sessions[0].cwd == "/tmp/project")
    }

    @Test("Update session status via report")
    func updateStatus() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentpong-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let writer = SessionWriter(sessionsDir: tmpDir)
        let reader = SessionReader(primaryDir: tmpDir, agentPingDir: nil)

        try writer.report(sessionId: "session-1", event: "start")
        try writer.report(sessionId: "session-1", event: "error")

        let sessions = reader.readAll()
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .error)
    }

    @Test("Empty/nonexistent directory returns empty array")
    func emptyDir() {
        let nonexistent = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        let reader = SessionReader(primaryDir: nonexistent, agentPingDir: nil)
        #expect(reader.readAll().isEmpty)
    }
}
