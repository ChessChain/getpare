// Helper/Sources/Recovery/RecoveryStore.swift
//
// SQLite-backed (GRDB) store of removed items awaiting purge. Lives at
// ~/Library/Application Support/Pare/recovery.sqlite. WAL mode so the
// PurgeWorker can purge in the background while the UI reads.

import Foundation
import GRDB
import PareKit

public final class RecoveryStore {

    private let dbQueue: DatabaseQueue?
    private let log = PareLogger(.helper, category: "recovery-store")

    public init() {
        // TODO(P3): wire to real ~/Library/Application Support/Pare path.
        // For the scaffold we use an in-memory DB so swift test passes.
        do {
            let queue = try DatabaseQueue()
            try Self.makeMigrations().migrate(queue)
            self.dbQueue = queue
        } catch {
            log.error("RecoveryStore init failed (running degraded): \(error.localizedDescription)")
            self.dbQueue = nil
        }
    }

    public func list() throws -> [RecoveryItem] {
        // TODO(P3): SELECT * FROM recovery_items WHERE restore_state = 'available'
        []
    }

    public func restore(itemIDs: [UUID]) throws -> RestoreReport {
        // TODO(P3): move archivedPath → originalPath, handle conflicts.
        RestoreReport(restoredCount: 0, conflicts: [])
    }

    public func purge(olderThan date: Date) throws -> PurgeReport {
        // TODO(P3): physical remove archived files; mark rows .purged.
        PurgeReport(purgedCount: 0, bytesFreed: 0)
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
            try db.create(index: "idx_recovery_purges_at",
                          on: "recovery_items", columns: ["purges_at"])
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
