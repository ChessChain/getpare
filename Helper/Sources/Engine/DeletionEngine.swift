// Helper/Sources/Engine/DeletionEngine.swift
//
// The only path that touches user data destructively. Every operation
// re-validates against ProtectedPaths and writes an audit log line at
// ~/Library/Logs/Pare/audit.log per Technical Design §7.

import Foundation
import PareKit

public final class DeletionEngine {

    public static let shared = DeletionEngine()
    private let log = PareLogger(.audit, category: "deletion")

    private init() {}

    public func moveToRecoveryBin(
        itemIDs: [UUID],
        orchestrator: ScannerOrchestrator,
        recoveryStore: RecoveryStore
    ) async throws -> CleanupReport {
        // TODO(P3):
        // 1. Resolve UUIDs → ScanItems via orchestrator results.
        // 2. For each, verify !ProtectedPaths.isProtected(item.path).
        // 3. Move to ~/Library/Application Support/Pare/Recovery/{scanID}/.
        // 4. Insert RecoveryItem row in SQLite via recoveryStore.
        // 5. Append audit log line: timestamp, path, bytes, reason.
        let report = CleanupReport(
            movedCount: 0,
            bytesReclaimed: 0,
            skipped: [],
            scanID: UUID()
        )
        log.info("Cleanup completed: moved=\(report.movedCount) bytes=\(report.bytesReclaimed)")
        return report
    }
}
