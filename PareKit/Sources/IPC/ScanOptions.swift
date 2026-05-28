// PareKit/IPC/ScanOptions.swift

import Foundation

public struct ScanOptions: Codable, Sendable {
    public var categories: Set<Category>
    /// Large File threshold. Default 100 MB per BRD FR-04.
    public var largeFileThresholdBytes: Int64
    /// If true, the helper hashes files > 5 GB. Slower; off by default.
    public var deepScan: Bool

    public init(
        categories: Set<Category> = Set(Category.allCases),
        largeFileThresholdBytes: Int64 = 100 * 1024 * 1024,
        deepScan: Bool = false
    ) {
        self.categories = categories
        self.largeFileThresholdBytes = largeFileThresholdBytes
        self.deepScan = deepScan
    }
}

public struct ScanHandle: Codable, Sendable, Hashable {
    public let id: UUID
    public init(id: UUID = UUID()) { self.id = id }
}

public struct ScanProgress: Codable, Sendable {
    public let percent: Double          // 0.0 ... 1.0
    public let currentTask: String      // e.g. "Detecting duplicates"
    public let currentPath: String      // e.g. "~/Library/Caches/com.apple.Safari"
    public let filesScanned: Int
    public let bytesFoundSoFar: Int64
    public let estimatedSecondsLeft: Int?

    public init(
        percent: Double,
        currentTask: String,
        currentPath: String,
        filesScanned: Int,
        bytesFoundSoFar: Int64,
        estimatedSecondsLeft: Int?
    ) {
        self.percent = percent
        self.currentTask = currentTask
        self.currentPath = currentPath
        self.filesScanned = filesScanned
        self.bytesFoundSoFar = bytesFoundSoFar
        self.estimatedSecondsLeft = estimatedSecondsLeft
    }
}
