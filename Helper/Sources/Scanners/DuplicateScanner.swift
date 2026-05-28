// Helper/Sources/Scanners/DuplicateScanner.swift
//
// FR-05 — group files by size first (cheap), then hash each candidate
// group (SHA-256, BLAKE3 for >100 MB per ADR-005). Keep the canonical
// copy; mark the rest as duplicates.

import Foundation
import PareKit

public struct DuplicateScanner: Scanner {
    public let category: PareKit.Category = .duplicate
    public init() {}

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        // TODO(P3): two-pass impl: size buckets → hash buckets → keep heuristic.
        return []
    }
}
