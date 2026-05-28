// Helper/Sources/Engine/ProtectedPaths.swift
//
// Hardcoded deny-list applied BEFORE any scanner runs and re-checked by
// the DeletionEngine before any file is touched. The engine is the last
// line of defence — even if the UI requests deletion of one of these,
// the engine refuses. See Technical Design §6.3.

import Foundation
import SystemConfiguration

public enum ProtectedPaths {
    /// System-level path prefixes that may never be scanned or deleted.
    private static let systemPrefixes: [String] = [
        "/System",
        "/Library/Apple",
        "/Library/Application Support/com.apple.TCC",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var/db",
        "/private/var/folders",
        "/dev",
        "/cores",
    ]

    /// User-relative suffixes appended to the target user's home directory.
    private static let userSuffixes: [String] = [
        "/Library/Mobile Documents",
        "/Library/Keychains",
        "/Library/CloudStorage",
    ]

    /// Resolves all protected prefixes for a given user home directory.
    /// The helper runs as root, so `NSHomeDirectory()` returns `/var/root`
    /// — callers must pass the actual target user's home.
    public static func prefixes(forUserHome home: String) -> [String] {
        systemPrefixes + userSuffixes.map { home + $0 }
    }

    /// Resolve the console (GUI-session) user's home directory.
    /// Falls back to `NSHomeDirectory()` when no console user is found.
    public static func currentUserHome() -> String {
        // SCDynamicStoreCopyConsoleUser returns the logged-in GUI user even
        // when the caller is running as root (privileged helper).
        var uid: uid_t = 0
        if let userName = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as String?,
           let pw = getpwnam(userName) {
            return String(cString: pw.pointee.pw_dir)
        }
        return NSHomeDirectory()
    }

    public static func isProtected(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let allPrefixes = prefixes(forUserHome: currentUserHome())
        return allPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}
