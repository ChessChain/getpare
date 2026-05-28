// Helper/Sources/Scanners/UninstallerScanner.swift
//
// FR-07 — apps + their preference / cache / support residue. Also
// surfaces residue left behind by already-uninstalled apps.

import Foundation
import PareKit

public struct UninstallerScanner: Scanner {
    public let category: PareKit.Category = .uninstaller
    public init() {}

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        // TODO(P3): enumerate /Applications + ~/Applications; for each .app,
        // collect bundle-id-keyed residue from ~/Library/{Preferences,
        // Caches, Application Support, Containers, Group Containers}.
        return []
    }
}
