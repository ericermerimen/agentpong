import Foundation
import os

private let logger = Logger(subsystem: "com.agentpong", category: "SessionWriter")

/// Writes session JSON files to ~/.agentpong/sessions/
/// Called by the CLI `agentpong report` command
public final class SessionWriter {
    private let sessionsDir: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(sessionsDir: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.sessionsDir = sessionsDir ?? home.appendingPathComponent(".agentpong/sessions")
    }

    /// Ensure the sessions directory exists
    public func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    }

    /// Write or update a session file based on a hook event
    public func report(
        sessionId: String,
        event: String,
        status: String? = nil,
        cwd: String? = nil,
        pid: Int? = nil,
        taskDescription: String? = nil
    ) throws {
        try ensureDirectory()

        let filePath = sessionsDir.appendingPathComponent("\(sessionId).json")

        // Load existing session or create new
        var session: Session
        if let data = try? Data(contentsOf: filePath),
           let existing = try? decoder.decode(Session.self, from: data) {
            session = existing
        } else {
            session = Session(id: sessionId)
        }

        // Update based on event
        switch event {
        case "start":
            session.status = .running
            if let cwd = cwd {
                session.cwd = cwd
                session.name = (cwd as NSString).lastPathComponent
            }
        case "stop":
            session.status = .done
        case "active":
            session.status = .running
        case "idle":
            session.status = .idle
        case "error":
            session.status = .error
        case "needsInput":
            session.status = .needsInput
            session.isFreshIdle = false
        case "notify":
            // Notification doesn't change status, just updates timestamp
            break
        default:
            logger.warning("Unknown event: \(event)")
        }

        // Apply optional overrides
        if let status = status, let s = SessionStatus(rawValue: status) {
            session.status = s
        }
        if let cwd = cwd {
            session.cwd = cwd
            if session.name == nil {
                session.name = (cwd as NSString).lastPathComponent
            }
        }
        if let pid = pid {
            session.pid = pid
        }
        if let desc = taskDescription {
            session.taskDescription = desc
        }

        session.lastUpdated = Date()

        // Write
        let data = try encoder.encode(session)
        try data.write(to: filePath, options: .atomic)

        logger.info("Session \(sessionId) updated: \(session.status.rawValue)")

        // Clean up done sessions after a delay (remove file if done for >60s)
        if session.status == .done {
            cleanupDoneSession(filePath: filePath, after: 60)
        }
    }

    /// Remove a session file
    public func remove(sessionId: String) throws {
        let filePath = sessionsDir.appendingPathComponent("\(sessionId).json")
        try? FileManager.default.removeItem(at: filePath)
    }

    private func cleanupDoneSession(filePath: URL, after seconds: TimeInterval) {
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
            try? FileManager.default.removeItem(at: filePath)
            logger.info("Cleaned up done session: \(filePath.lastPathComponent)")
        }
    }
}
