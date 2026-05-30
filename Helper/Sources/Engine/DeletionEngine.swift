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

    /// Items live in the Recovery Bin for 30 days before the PurgeWorker
    /// physically removes them.
    public static let retentionInterval: TimeInterval = 30 * 24 * 60 * 60

    private init() {}

    public func moveToRecoveryBin(
        itemIDs: [UUID],
        orchestrator: ScannerOrchestrator,
        recoveryStore: RecoveryStore
    ) async throws -> CleanupReport {
        let fm = FileManager.default
        let now = Date()
        let purgesAt = now.addingTimeInterval(Self.retentionInterval)

        var movedCount = 0
        var bytesReclaimed: Int64 = 0
        var skipped: [CleanupReport.SkippedItem] = []
        var reportScanID = UUID()

        for id in itemIDs {
            guard let resolved = await orchestrator.findItem(byID: id) else {
                skipped.append(
                    CleanupReport.SkippedItem(
                        path: URL(fileURLWithPath: "/"),
                        reason: "Item \(id.uuidString) not found in any active scan"
                    )
                )
                continue
            }
            let item = resolved.item
            reportScanID = resolved.handle.id

            // Defence in depth — the engine refuses protected paths even if
            // the scanner or UI somehow allowed them through.
            if ProtectedPaths.isProtected(item.path) {
                skipped.append(
                    CleanupReport.SkippedItem(path: item.path, reason: "Protected path")
                )
                log.warn("REFUSED protected: \(item.path.path)")
                continue
            }

            guard fm.fileExists(atPath: item.path.path) else {
                skipped.append(
                    CleanupReport.SkippedItem(path: item.path, reason: "File no longer exists")
                )
                continue
            }

            do {
                let archiveDir = try recoveryStore.archiveDirectory(for: resolved.handle.id)
                let archivedURL = Self.uniqueDestination(in: archiveDir, for: item.path)
                try fm.moveItem(at: item.path, to: archivedURL)

                let record = RecoveryItem(
                    originalPath: item.path,
                    archivedPath: archivedURL,
                    bytes: item.bytes,
                    category: item.category,
                    removedAt: now,
                    purgesAt: purgesAt,
                    scanID: resolved.handle.id
                )
                try recoveryStore.insert(record)

                log.info("MOVED \(item.path.path) → \(archivedURL.path) (\(item.bytes) bytes)")
                movedCount += 1
                bytesReclaimed += item.bytes
            } catch {
                skipped.append(
                    CleanupReport.SkippedItem(
                        path: item.path,
                        reason: "Move failed: \(error.localizedDescription)"
                    )
                )
                log.error("FAILED \(item.path.path): \(error.localizedDescription)")
            }
        }

        log.info(
            "Cleanup completed: moved=\(movedCount) bytes=\(bytesReclaimed) "
            + "skipped=\(skipped.count) scan=\(reportScanID.uuidString)"
        )
        return CleanupReport(
            movedCount: movedCount,
            bytesReclaimed: bytesReclaimed,
            skipped: skipped,
            scanID: reportScanID
        )
    }

    /// Picks `<filename>`, then `<base>-2.<ext>`, `<base>-3.<ext>`, etc., so
    /// two items with the same name from different folders don't collide
    /// inside the per-scan archive directory.
    private static func uniqueDestination(in dir: URL, for original: URL) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent(original.lastPathComponent)
        if !fm.fileExists(atPath: candidate.path) { return candidate }

        let base = original.deletingPathExtension().lastPathComponent
        let ext = original.pathExtension
        for n in 2...1000 {
            var name = "\(base)-\(n)"
            if !ext.isEmpty { name += ".\(ext)" }
            candidate = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        var fallback = "\(base)-\(UUID().uuidString)"
        if !ext.isEmpty { fallback += ".\(ext)" }
        return dir.appendingPathComponent(fallback)
    }
}
