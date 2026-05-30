// Helper/Sources/Recovery/RecoveryStore.swift
//
// SQLite-backed (GRDB) store of removed items awaiting purge. The default
// production path is `<console-user-home>/Library/Application Support/Pare/`,
// which the helper resolves via `ProtectedPaths.currentUserHome()` because it
// runs as root and NSHomeDirectory() would point at /var/root.
// WAL mode is enabled so the PurgeWorker can purge in the background while
// the UI reads.

import Foundation
import GRDB
import PareKit

public final class RecoveryStore {

    /// Where archived files for a given scan are kept on disk.
    public let archivesDirectory: URL

    private let dbQueue: DatabaseQueue?
    private let log = PareLogger(.helper, category: "recovery-store")

    /// `baseDirectory` is the parent that contains both `recovery.sqlite`
    /// and the `Recovery/` archives folder. Defaults to the production path.
    public init(baseDirectory: URL = RecoveryStore.defaultBaseURL()) {
        let fm = FileManager.default
        let archives = baseDirectory.appendingPathComponent("Recovery", isDirectory: true)
        self.archivesDirectory = archives

        do {
            try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            try fm.createDirectory(at: archives, withIntermediateDirectories: true)

            var config = Configuration()
            config.prepareDatabase { db in
                try db.execute(sql: "PRAGMA journal_mode = WAL")
            }
            let dbURL = baseDirectory.appendingPathComponent("recovery.sqlite")
            let queue = try DatabaseQueue(path: dbURL.path, configuration: config)
            try Self.makeMigrations().migrate(queue)
            self.dbQueue = queue
            log.info("RecoveryStore opened at \(dbURL.path)")
        } catch {
            log.error("RecoveryStore init failed (running degraded): \(error.localizedDescription)")
            self.dbQueue = nil
        }
    }

    /// Production base path resolved against the console user's home (the helper
    /// itself runs as root, so we can't trust `NSHomeDirectory()`).
    public static func defaultBaseURL() -> URL {
        let home = ProtectedPaths.currentUserHome()
        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Application Support/Pare", isDirectory: true)
    }

    /// Per-scan archive directory used by `DeletionEngine` when moving files.
    public func archiveDirectory(for scanID: UUID) throws -> URL {
        let dir = archivesDirectory.appendingPathComponent(scanID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Insert (called by DeletionEngine after a successful archive)

    public func insert(_ item: RecoveryItem) throws {
        guard let dbQueue = dbQueue else { return }
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO recovery_items
                (id, original_path, archived_path, bytes, category,
                 removed_at, purges_at, scan_id, restore_state)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    item.id.uuidString,
                    item.originalPath.path,
                    item.archivedPath.path,
                    item.bytes,
                    item.category.rawValue,
                    item.removedAt,
                    item.purgesAt,
                    item.scanID.uuidString,
                    item.restoreState.rawValue,
                ]
            )
        }
    }

    // MARK: List

    public func list() throws -> [RecoveryItem] {
        guard let dbQueue = dbQueue else { return [] }
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, original_path, archived_path, bytes, category,
                       removed_at, purges_at, scan_id, restore_state
                FROM recovery_items
                WHERE restore_state = 'available'
                ORDER BY removed_at DESC
                """
            )
            return rows.compactMap(Self.itemFromRow)
        }
    }

    // MARK: Restore

    public func restore(itemIDs: [UUID]) throws -> RestoreReport {
        guard let dbQueue = dbQueue else {
            return RestoreReport(restoredCount: 0, conflicts: [])
        }

        var restored = 0
        var conflicts: [RestoreReport.Conflict] = []
        let fm = FileManager.default

        try dbQueue.write { db in
            for id in itemIDs {
                guard
                    let row = try Row.fetchOne(
                        db,
                        sql: """
                        SELECT id, original_path, archived_path, bytes, category,
                               removed_at, purges_at, scan_id, restore_state
                        FROM recovery_items
                        WHERE id = ? AND restore_state = 'available'
                        """,
                        arguments: [id.uuidString]
                    ),
                    let item = Self.itemFromRow(row)
                else { continue }

                var resolvedURL = item.originalPath
                var conflictReason: String?

                if fm.fileExists(atPath: item.originalPath.path) {
                    resolvedURL = Self.uniqueRestoredURL(for: item.originalPath)
                    conflictReason = "Original location already occupied"
                }

                try? fm.createDirectory(
                    at: resolvedURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                do {
                    try fm.moveItem(at: item.archivedPath, to: resolvedURL)
                    try db.execute(
                        sql: "UPDATE recovery_items SET restore_state = 'restored' WHERE id = ?",
                        arguments: [id.uuidString]
                    )
                    try db.execute(
                        sql: """
                        INSERT INTO restore_log (item_id, restored_at, resolved_path)
                        VALUES (?, ?, ?)
                        """,
                        arguments: [id.uuidString, Date(), resolvedURL.path]
                    )
                    restored += 1
                    if let reason = conflictReason {
                        conflicts.append(
                            RestoreReport.Conflict(
                                originalPath: item.originalPath,
                                resolvedPath: resolvedURL,
                                reason: reason
                            )
                        )
                    }
                } catch {
                    conflicts.append(
                        RestoreReport.Conflict(
                            originalPath: item.originalPath,
                            resolvedPath: resolvedURL,
                            reason: "Move failed: \(error.localizedDescription)"
                        )
                    )
                }
            }
        }

        log.info("Restored \(restored)/\(itemIDs.count) items, \(conflicts.count) conflicts")
        return RestoreReport(restoredCount: restored, conflicts: conflicts)
    }

    // MARK: Purge

    public func purge(olderThan date: Date) throws -> PurgeReport {
        guard let dbQueue = dbQueue else {
            return PurgeReport(purgedCount: 0, bytesFreed: 0)
        }

        var purged = 0
        var bytesFreed: Int64 = 0
        let fm = FileManager.default

        try dbQueue.write { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, archived_path, bytes
                FROM recovery_items
                WHERE restore_state = 'available' AND purges_at <= ?
                """,
                arguments: [date]
            )
            for row in rows {
                guard
                    let idString: String = row["id"],
                    let archivedPath: String = row["archived_path"],
                    let bytes: Int64 = row["bytes"]
                else { continue }
                try? fm.removeItem(at: URL(fileURLWithPath: archivedPath))
                try db.execute(
                    sql: "UPDATE recovery_items SET restore_state = 'purged' WHERE id = ?",
                    arguments: [idString]
                )
                purged += 1
                bytesFreed += bytes
            }
        }

        log.info("Purged \(purged) items, freed \(bytesFreed) bytes")
        return PurgeReport(purgedCount: purged, bytesFreed: bytesFreed)
    }

    // MARK: Row decoding

    private static func itemFromRow(_ row: Row) -> RecoveryItem? {
        guard
            let idString: String = row["id"],
            let id = UUID(uuidString: idString),
            let originalPath: String = row["original_path"],
            let archivedPath: String = row["archived_path"],
            let bytes: Int64 = row["bytes"],
            let categoryRaw: String = row["category"],
            let category = Category(rawValue: categoryRaw),
            let removedAt: Date = row["removed_at"],
            let purgesAt: Date = row["purges_at"],
            let scanIDString: String = row["scan_id"],
            let scanID = UUID(uuidString: scanIDString),
            let stateRaw: String = row["restore_state"],
            let state = RestoreState(rawValue: stateRaw)
        else { return nil }

        return RecoveryItem(
            id: id,
            originalPath: URL(fileURLWithPath: originalPath),
            archivedPath: URL(fileURLWithPath: archivedPath),
            bytes: bytes,
            category: category,
            removedAt: removedAt,
            purgesAt: purgesAt,
            scanID: scanID,
            restoreState: state
        )
    }

    /// Picks `<name> (restored).<ext>`, then `(restored 2)`, etc., up to 100.
    private static func uniqueRestoredURL(for original: URL) -> URL {
        let dir = original.deletingLastPathComponent()
        let base = original.deletingPathExtension().lastPathComponent
        let ext = original.pathExtension
        let fm = FileManager.default
        for i in 1...100 {
            let suffix = i == 1 ? "(restored)" : "(restored \(i))"
            var name = "\(base) \(suffix)"
            if !ext.isEmpty { name += ".\(ext)" }
            let candidate = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        // Astronomically unlikely fallback — append a UUID to guarantee uniqueness.
        var name = "\(base) (restored \(UUID().uuidString))"
        if !ext.isEmpty { name += ".\(ext)" }
        return dir.appendingPathComponent(name)
    }

    // MARK: GRDB migrations

    private static func makeMigrations() -> DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1_recovery_items") { db in
            try db.create(table: "recovery_items") { t in
                t.column("id", .text).primaryKey()
                t.column("original_path", .text).notNull()
                t.column("archived_path", .text).notNull()
                t.column("bytes", .integer).notNull()
                t.column("category", .text).notNull()
                t.column("removed_at", .datetime).notNull()
                t.column("purges_at", .datetime).notNull()
                t.column("scan_id", .text).notNull()
                t.column("restore_state", .text).notNull().defaults(to: "available")
            }
            try db.create(
                index: "idx_recovery_purges_at",
                on: "recovery_items",
                columns: ["purges_at"]
            )
        }
        m.registerMigration("v2_scans") { db in
            try db.create(table: "scans") { t in
                t.column("id", .text).primaryKey()
                t.column("started_at", .datetime).notNull()
                t.column("completed_at", .datetime)
                t.column("bytes_reclaimed", .integer)
            }
        }
        m.registerMigration("v3_restore_log") { db in
            try db.create(table: "restore_log") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("item_id", .text).notNull()
                t.column("restored_at", .datetime).notNull()
                t.column("resolved_path", .text).notNull()
            }
        }
        return m
    }
}
