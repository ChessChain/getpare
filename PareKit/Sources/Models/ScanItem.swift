// PareKit/Models/ScanItem.swift
//
// Canonical representation of a single reclaimable item produced by a
// scanner. Crosses the XPC boundary, so it is Codable + Sendable.

import Foundation

public struct ScanItem: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let path: URL
    public let category: Category
    public let bytes: Int64
    public let lastModified: Date
    public let lastAccessed: Date
    public let contentHash: String?
    public let riskLevel: Risk
    public let groupID: UUID?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        path: URL,
        category: Category,
        bytes: Int64,
        lastModified: Date,
        lastAccessed: Date,
        contentHash: String? = nil,
        riskLevel: Risk,
        groupID: UUID? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.path = path
        self.category = category
        self.bytes = bytes
        self.lastModified = lastModified
        self.lastAccessed = lastAccessed
        self.contentHash = contentHash
        self.riskLevel = riskLevel
        self.groupID = groupID
        self.metadata = metadata
    }
}
