// App/Sources/Utilities/PermissionManager.swift
//
// Checks Full Disk Access using multiple probe paths.
// Persists the grant status so we don't re-prompt after the user has granted.

import AppKit
import Combine

public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public var hasFullDiskAccess: Bool = false

    private var pollTimer: AnyCancellable?
    private let defaults = UserDefaults.standard
    private let persistKey = "pare.fda.granted"

    private init() {
        // Check persisted status first
        let persisted = defaults.bool(forKey: persistKey)
        let live = Self.checkFDA()

        if live {
            // Confirmed live — save it
            hasFullDiskAccess = true
            defaults.set(true, forKey: persistKey)
        } else if persisted {
            // User granted before but check fails now (could be re-launch timing)
            // Re-verify with a short delay
            hasFullDiskAccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                let recheck = Self.checkFDA()
                if recheck {
                    self?.hasFullDiskAccess = true
                } else {
                    // FDA was revoked — reset
                    self?.hasFullDiskAccess = false
                    self?.defaults.set(false, forKey: self?.persistKey ?? "")
                }
            }
        } else {
            hasFullDiskAccess = false
        }
    }

    /// Probe FDA using multiple protected paths.
    /// Returns true if ANY of them is readable (meaning we have FDA).
    public static func checkFDA() -> Bool {
        let probePaths = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "/Library/Preferences/com.apple.TimeMachine.plist",
            NSHomeDirectory() + "/Library/Mail/V10",
            NSHomeDirectory() + "/Library/Safari/Bookmarks.plist",
            NSHomeDirectory() + "/Library/Messages/chat.db",
        ]

        for path in probePaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return true
            }
        }

        // Also try to actually read a byte from the TCC database
        let tccPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        if let fh = FileHandle(forReadingAtPath: tccPath) {
            fh.closeFile()
            return true
        }

        return false
    }

    /// Open System Settings to the FDA pane and start polling.
    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    /// Poll every 2 seconds to detect FDA grant. Auto-stops when granted.
    public func startPolling() {
        pollTimer?.cancel()
        pollTimer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let granted = Self.checkFDA()
                if granted {
                    self.hasFullDiskAccess = true
                    self.defaults.set(true, forKey: self.persistKey)
                    self.pollTimer?.cancel()
                    self.pollTimer = nil
                }
            }
    }

    /// Manually mark as granted (e.g. user confirms they did it)
    public func markAsGranted() {
        hasFullDiskAccess = true
        defaults.set(true, forKey: persistKey)
    }

    /// Reset the persisted status (for testing)
    public func reset() {
        hasFullDiskAccess = false
        defaults.removeObject(forKey: persistKey)
    }

    public func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }
}
