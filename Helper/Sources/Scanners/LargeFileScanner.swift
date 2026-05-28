// Helper/Sources/Scanners/LargeFileScanner.swift
//
// FR-04 — files above options.largeFileThresholdBytes. Sorted client-side.

import Foundation
import PareKit

public struct LargeFileScanner: Scanner {
    public let category: PareKit.Category = .largeFile
    public init() {}

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        // TODO(P3): walk user home + ~/Movies + ~/Music + ~/Pictures;
        // filter by size threshold and recent-access cutoff.
        return []
    }
}
