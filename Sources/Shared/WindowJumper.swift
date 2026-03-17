import AppKit
import os

private let logger = Logger(subsystem: "com.agentpong", category: "WindowJumper")

/// Finds and activates the terminal window running a Claude Code session.
///
/// Flow:
///   1. Session stores Claude's PID (injected by hook-sender.sh)
///   2. Walk process tree up from Claude PID to find the terminal app
///   3. Activate that app via NSRunningApplication
///
/// Supported terminals: Terminal.app, iTerm2, Ghostty, Warp, Alacritty, kitty, VS Code
public final class WindowJumper {

    public static let shared = WindowJumper()

    /// Known terminal bundle IDs for process tree matching.
    private static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",  // Cursor
    ]

    /// Jump to the terminal window running the given session.
    /// Returns true if a window was activated.
    @discardableResult
    public func jump(to session: Session) -> Bool {
        guard let claudePid = session.pid, claudePid > 0 else {
            logger.warning("No PID for session \(session.id) -- cannot jump")
            return false
        }

        // Walk up from Claude's PID to find the terminal app
        if let app = findTerminalApp(fromPid: pid_t(claudePid)) {
            logger.info("Jumping to \(app.localizedName ?? "unknown") (pid \(app.processIdentifier)) for session \(session.id)")
            app.activate()
            return true
        }

        // Fallback: try activating the PID directly (might be the app itself)
        if let app = NSRunningApplication(processIdentifier: pid_t(claudePid)) {
            logger.info("Fallback: activating pid \(claudePid) directly for session \(session.id)")
            app.activate()
            return true
        }

        // Last resort: try to find a terminal with matching cwd in its windows
        if let cwd = session.cwd, let app = findTerminalByCwd(cwd) {
            logger.info("Found terminal by cwd match for session \(session.id)")
            app.activate()
            return true
        }

        logger.warning("Could not find terminal for session \(session.id) (pid \(claudePid))")
        return false
    }

    /// Walk up the process tree from the given PID until we find a running GUI app.
    private func findTerminalApp(fromPid startPid: pid_t) -> NSRunningApplication? {
        // Build a set of running terminal apps for fast lookup
        let runningApps = NSWorkspace.shared.runningApplications
        var pidToApp: [pid_t: NSRunningApplication] = [:]
        for app in runningApps where app.activationPolicy == .regular {
            pidToApp[app.processIdentifier] = app
        }

        // Walk up the process tree (max 20 levels to avoid infinite loops)
        var currentPid = startPid
        for _ in 0..<20 {
            if currentPid <= 1 { break }

            // Check if this PID is a running GUI app
            if let app = pidToApp[currentPid] {
                // Prefer known terminal apps
                if let bundleId = app.bundleIdentifier,
                   WindowJumper.terminalBundleIDs.contains(bundleId) {
                    return app
                }
                // Accept any GUI app (could be an unknown terminal)
                return app
            }

            // Move to parent
            let parentPid = getParentPID(of: currentPid)
            if parentPid == currentPid || parentPid <= 1 { break }
            currentPid = parentPid
        }

        return nil
    }

    /// Find a terminal app that might have a window with matching cwd.
    /// Uses AppleScript to check window titles for the directory name.
    private func findTerminalByCwd(_ cwd: String) -> NSRunningApplication? {
        let dirName = (cwd as NSString).lastPathComponent
        guard !dirName.isEmpty else { return nil }

        // Check running terminal apps
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier,
                  WindowJumper.terminalBundleIDs.contains(bundleId) else { continue }

            // Try AppleScript to find window with matching title
            if terminalHasWindow(bundleId: bundleId, containing: dirName) {
                return app
            }
        }
        return nil
    }

    /// Check if a terminal app has a window whose title contains the given string.
    private func terminalHasWindow(bundleId: String, containing text: String) -> Bool {
        let script: String
        switch bundleId {
        case "com.apple.Terminal":
            script = "tell application \"Terminal\" to get name of every window"
        case "com.googlecode.iterm2":
            script = "tell application \"iTerm2\" to get name of every window"
        default:
            return false
        }

        guard let appleScript = NSAppleScript(source: script) else { return false }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        guard error == nil else { return false }

        let resultString = result.stringValue ?? ""
        return resultString.localizedCaseInsensitiveContains(text)
    }

    /// Get the parent PID of a process using sysctl.
    private func getParentPID(of pid: pid_t) -> pid_t {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0 else { return 0 }
        return info.kp_eproc.e_ppid
    }
}
