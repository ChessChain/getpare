// PareKit/Models/RecoveryItem.swift
//
// One row in the 30-day Recovery Bin. The RecoveryStore in Helper is the
// owner; the App reads via XPC for display only.

import Foundation

public enum RestoreState: String, Codable, Sendable {
    case available
    case restored
    case purged
}

public struct RecoveryItem: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let originalPath: URL
    public let archivedPath: URL
    public let bytes: Int64
    public let category: Category
    public let removedAt: Date
    public let purgesAt: Date
    public let scanID: UUID
    public let restoreState: RestoreState

    public init(
        id: UUID = UUID(),
        originalPath: URL,
        archivedPath: URL,
        bytes: Int64,
        category: Category,
        removedAt: Date,
        purgesAt: Date,
        scanID: UUID,
        restoreState: RestoreState = .available
    ) {
        self.id = id
        self.originalPath = originalPath
        self.archivedPath = archivedPath
        self.bytes = bytes
        self.category = category
        self.removedAt = removedAt
        self.purgesAt = purgesAt
        self.scanID = scanID
        self.restoreState = restoreState
    }
}
