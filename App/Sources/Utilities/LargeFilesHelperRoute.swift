// App/Sources/Utilities/LargeFilesHelperRoute.swift
//
// Run a scan via the privileged helper and surface `[ScanItem]`. Returns
// `nil` when the helper isn't reachable so callers can fall back to their
// direct-FS code path.

import Foundation
import PareKit

enum HelperScanRoute {

    /// Run a scan for the given categories via the helper. Polls progress
    /// every 200ms and calls `progress` on the calling actor.
    /// Returns nil if the helper is not currently enabled or the call fails.
    static func fetch(
        categories: Set<PareKit.Category>,
        thresholdBytes: Int64 = 100_000_000,
        deepScan: Bool = false,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async -> [ScanItem]? {
        let status = await MainActor.run { HelperInstaller.shared.status }
        guard status == .enabled else { return nil }

        let client = PareHelperClient()
        let options = ScanOptions(
            categories: categories,
            largeFileThresholdBytes: thresholdBytes,
            deepScan: deepScan
        )

        do {
            let handle = try await client.startScan(options: options)
            while !Task.isCancelled {
                if let p = try await client.scanProgress(handle: handle) {
                    progress(p)
                    if p.percent >= 1.0 { break }
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            try Task.checkCancellation()
            return try await client.scanResults(handle: handle)
        } catch {
            return nil
        }
    }
}

/// Thin convenience for the Large Files screen.
enum LargeFilesHelperRoute {
    static func fetch(
        thresholdBytes: Int64 = 100_000_000,
        deepScan: Bool = false,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async -> [ScanItem]? {
        await HelperScanRoute.fetch(
            categories: [.largeFile],
            thresholdBytes: thresholdBytes,
            deepScan: deepScan,
            progress: progress
        )
    }
}
