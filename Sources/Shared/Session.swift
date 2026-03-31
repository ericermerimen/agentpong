import Foundation

/// Status of a Claude Code session
public enum SessionStatus: String, Codable, CaseIterable {
    case running
    case idle
    case done
    case needsInput
    case error
    case unavailable
}

/// Zone in the office where a character should be placed
public enum OfficeZone: String {
    case desk
    case lounge
    case debugStation
    case door
}

/// A Claude Code session, read from ~/.agentpong/sessions/
public struct Session: Codable, Identifiable, Equatable {
    public let id: String
    public var status: SessionStatus
    public var name: String?
    public var cwd: String?
    public var app: String?
    public var pid: Int?
    public var taskDescription: String?
    public var contextPercent: Double?
    public var cost: Double?
    public var isFreshIdle: Bool?
    public var lastUpdated: Date

    public init(
        id: String,
        status: SessionStatus = .idle,
        name: String? = nil,
        cwd: String? = nil,
        app: String? = nil,
        pid: Int? = nil,
        taskDescription: String? = nil,
        contextPercent: Double? = nil,
        cost: Double? = nil,
        isFreshIdle: Bool? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.name = name
        self.cwd = cwd
        self.app = app
        self.pid = pid
        self.taskDescription = taskDescription
        self.contextPercent = contextPercent
        self.cost = cost
        self.isFreshIdle = isFreshIdle
        self.lastUpdated = lastUpdated
    }

    /// Which office zone this session's character belongs in
    public var zone: OfficeZone {
        switch status {
        case .running:
            return .desk
        case .idle:
            return isFreshIdle == true ? .lounge : .lounge
        case .needsInput:
            return .lounge
        case .error:
            return .debugStation
        case .done, .unavailable:
            return .door
        }
    }

    /// Display name for the session
    public var displayName: String {
        // Check cwd first -- if it's home dir, always show "~" regardless of stored name
        if let cwd = cwd, cwd == NSHomeDirectory() {
            return "~"
        }
        if let name = name, !name.isEmpty {
            return name
        }
        if let cwd = cwd {
            return (cwd as NSString).lastPathComponent
        }
        return String(id.prefix(8))
    }

    /// Whether this session should have a visible character
    public var isVisible: Bool {
        status != .done && status != .unavailable
    }
}
