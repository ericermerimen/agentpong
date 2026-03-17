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

    /// Stale threshold: sessions not updated in 5 minutes are considered gone
    private let staleThreshold: TimeInterval = 300

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

        // Filter stale sessions
        let now = Date()
        sessions = sessions.filter { session in
            now.timeIntervalSince(session.lastUpdated) < staleThreshold
        }

        return sessions.sorted { $0.lastUpdated > $1.lastUpdated }
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
