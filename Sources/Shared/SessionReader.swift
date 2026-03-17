import Foundation
import os

private let logger = Logger(subsystem: "com.agentpong", category: "SessionReader")

/// Reads session JSON files from disk
public final class SessionReader {
    /// Primary session directory (standalone)
    private let primaryDir: URL
    /// Optional AgentPing compatibility directory
    private let agentPingDir: URL?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Stale threshold: sessions not updated in 2 hours are considered gone.
    /// This is a fallback -- primary detection uses kill(pid, 0) process liveness.
    private let staleThreshold: TimeInterval = 7200

    public init(
        primaryDir: URL? = nil,
        agentPingDir: URL? = nil
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.primaryDir = primaryDir ?? home.appendingPathComponent(".agentpong/sessions")
        self.agentPingDir = agentPingDir ?? home.appendingPathComponent(".agentping/sessions")
    }

    /// Read all active sessions from disk
    public func readAll() -> [Session] {
        var sessions: [Session] = []

        // Read from primary directory
        sessions.append(contentsOf: readDirectory(primaryDir))

        // Read from AgentPing directory if it exists (optional compat)
        if let apDir = agentPingDir {
            let apSessions = readDirectory(apDir)
            // Merge: primary takes precedence by session ID
            let primaryIds = Set(sessions.map(\.id))
            for session in apSessions where !primaryIds.contains(session.id) {
                sessions.append(session)
            }
        }

        // Filter: dead processes first (like AgentPing's markDeadProcessSessions),
        // then stale sessions as fallback
        let now = Date()
        sessions = sessions.filter { session in
            // Skip done/unavailable sessions
            guard session.isVisible else { return false }

            // Primary check: is the process still alive? (AgentPing approach)
            if let pid = session.pid, pid > 0 {
                if !isProcessAlive(pid_t(pid)) {
                    logger.info("Session \(session.id) process \(pid) is dead, filtering out")
                    return false
                }
            }

            // Fallback: stale threshold for sessions without PID
            return now.timeIntervalSince(session.lastUpdated) < staleThreshold
        }

        return sessions.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    /// Check if a process is alive using kill(pid, 0) syscall.
    /// Same approach as AgentPing's SessionManager.markDeadProcessSessions().
    /// - kill(pid, 0) returns 0 if process exists and we can signal it
    /// - errno == EPERM means process exists but we lack permission (still alive)
    private func isProcessAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    private func readDirectory(_ dir: URL) -> [Session] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else {
            return []
        }

        var sessions: [Session] = []
        do {
            let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }

            for file in files {
                do {
                    let data = try Data(contentsOf: file)
                    let session = try decoder.decode(Session.self, from: data)
                    sessions.append(session)
                } catch {
                    logger.warning("Failed to decode \(file.lastPathComponent): \(error.localizedDescription)")
                }
            }
        } catch {
            logger.warning("Failed to list \(dir.path): \(error.localizedDescription)")
        }

        return sessions
    }
}
