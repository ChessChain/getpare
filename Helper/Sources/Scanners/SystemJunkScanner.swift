// Helper/Sources/Scanners/SystemJunkScanner.swift
//
// FR-03 — user/system caches, logs, language files, broken preferences.
// NEVER touches /System, /usr, /bin — those live in ProtectedPaths.

import Foundation
import PareKit

public struct SystemJunkScanner: Scanner {
    public let category: PareKit.Category = .systemJunk
    public init() {}

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        // TODO(P3): enumerate ~/Library/Caches, ~/Library/Logs, language
        // .lproj bundles, broken preference files. See BRD FR-03.
        return []
    }
}
