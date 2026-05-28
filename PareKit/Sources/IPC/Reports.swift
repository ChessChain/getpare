// PareKit/IPC/Reports.swift
//
// Returned from cleanup / restore / purge operations across the XPC boundary.

import Foundation

public struct CleanupReport: Codable, Sendable {
    public let movedCount: Int
    public let bytesReclaimed: Int64
    public let skipped: [SkippedItem]
    public let scanID: UUID

    public struct SkippedItem: Codable, Sendable {
        public let path: URL
        public let reason: String
    }

    public init(movedCount: Int, bytesReclaimed: Int64, skipped: [SkippedItem], scanID: UUID) {
        self.movedCount = movedCount
        self.bytesReclaimed = bytesReclaimed
        self.skipped = skipped
        self.scanID = scanID
    }
}

public struct RestoreReport: Codable, Sendable {
    public let restoredCount: Int
    public let conflicts: [Conflict]

    public struct Conflict: Codable, Sendable {
        public let originalPath: URL
        public let resolvedPath: URL  // e.g. file (restored).ext
        public let reason: String
    }

    public init(restoredCount: Int, conflicts: [Conflict]) {
        self.restoredCount = restoredCount
        self.conflicts = conflicts
    }
}

public struct PurgeReport: Codable, Sendable {
    public let purgedCount: Int
    public let bytesFreed: Int64
    public init(purgedCount: Int, bytesFreed: Int64) {
        self.purgedCount = purgedCount
        self.bytesFreed = bytesFreed
    }
}
