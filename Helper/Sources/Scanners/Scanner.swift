// Helper/Sources/Scanners/Scanner.swift
//
// Every cleanup module conforms to this protocol. Scanners are stateless
// across runs and report progress incrementally to the orchestrator.

import Foundation
import PareKit

public protocol Scanner: Sendable {
    /// Identifies which category this scanner produces.
    var category: PareKit.Category { get }

    /// Performs the scan. Implementations should yield to Task.checkCancellation()
    /// often enough that user-initiated cancel feels instant (≤ 200ms).
    func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem]
}
