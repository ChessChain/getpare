// Helper/Sources/Recovery/PurgeWorker.swift
//
// Background worker that runs once per day and purges Recovery Bin
// entries older than 30 days. Surfaces a weekly digest notification.

import Foundation
import PareKit

public final class PurgeWorker {

    private let store: RecoveryStore
    private let log = PareLogger(.helper, category: "purge-worker")
    private var timerSource: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.clearpath.pare.purge-worker")

    /// Run the purge cycle once every 24 hours.
    private static let intervalSeconds: Int = 24 * 60 * 60

    public init(store: RecoveryStore) {
        self.store = store
    }

    public func start() {
        guard timerSource == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(
            deadline: .now() + .seconds(60), // first run 60 s after launch
            repeating: .seconds(Self.intervalSeconds),
            leeway: .seconds(30)
        )
        source.setEventHandler { [weak self] in self?.runOnce() }
        source.resume()
        timerSource = source
        log.info("PurgeWorker scheduled (every \(Self.intervalSeconds)s)")
    }

    public func stop() {
        timerSource?.cancel()
        timerSource = nil
    }

    public func runOnce() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        do {
            let report = try store.purge(olderThan: cutoff)
            log.info("Purge run: \(report.purgedCount) items, \(report.bytesFreed) bytes freed")
        } catch {
            log.error("Purge run failed: \(error.localizedDescription)")
        }
    }
}
