// Helper/Sources/Scanners/MailScanner.swift
//
// FR-08 — Apple Mail attachment cache. Apple Mail stores per-account data
// under `~/Library/Mail/V<n>/<account-UUID>/<mailbox>/Attachments/`. The
// attachments are re-downloadable from the server (where present) and are
// the dominant size driver inside the Mail container.
//
// Risk is `.caution`: while attachments are typically re-fetchable, the
// originating message may have been deleted from the server, in which
// case clearing the local cache loses the only copy. We deliberately
// never touch .mbox files themselves.

import Foundation
import PareKit

public struct MailScanner: Scanner {
    public let category: PareKit.Category = .mailCache

    public let roots: [URL]
    public let progressEveryNFiles: Int

    public init(roots: [URL]? = nil, progressEveryNFiles: Int = 500) {
        self.roots = roots ?? Self.defaultRoots()
        self.progressEveryNFiles = max(1, progressEveryNFiles)
    }

    private static func defaultRoots() -> [URL] {
        let home = URL(fileURLWithPath: ProtectedPaths.currentUserHome())
        return [home.appendingPathComponent("Library/Mail")]
    }

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .isRegularFileKey,
            .contentModificationDateKey,
            .contentAccessDateKey,
        ]
        var results: [ScanItem] = []
        var filesScanned = 0
        var bytesFound: Int64 = 0
        let totalRoots = max(1, roots.count)

        for (rootIdx, root) in roots.enumerated() {
            try Task.checkCancellation()
            guard fm.fileExists(atPath: root.path) else { continue }
            guard
                let enumerator = fm.enumerator(
                    at: root,
                    includingPropertiesForKeys: keys,
                    options: [.skipsPackageDescendants, .skipsHiddenFiles],
                    errorHandler: { _, _ in true }
                )
            else { continue }

            while let next = enumerator.nextObject() {
                try Task.checkCancellation()
                guard let url = next as? URL else { continue }
                filesScanned += 1

                if ProtectedPaths.isProtected(url) { continue }

                // Only files within an `Attachments/` segment are clearable.
                guard url.path.contains("/Attachments/") else { continue }

                guard
                    let values = try? url.resourceValues(forKeys: Set(keys)),
                    values.isRegularFile == true,
                    let rawSize = values.fileSize,
                    rawSize > 0
                else { continue }

                let size = Int64(rawSize)
                results.append(
                    ScanItem(
                        path: url,
                        category: .mailCache,
                        bytes: size,
                        lastModified: values.contentModificationDate ?? Date.distantPast,
                        lastAccessed: values.contentAccessDate ?? Date.distantPast,
                        riskLevel: .caution,
                        metadata: [
                            "subcategory": "attachment",
                            "filename": url.lastPathComponent,
                        ]
                    )
                )
                bytesFound += size

                if filesScanned % progressEveryNFiles == 0 {
                    progress(
                        ScanProgress(
                            percent: Double(rootIdx) / Double(totalRoots),
                            currentTask: "Scanning Mail attachments",
                            currentPath: url.path,
                            filesScanned: filesScanned,
                            bytesFoundSoFar: bytesFound,
                            estimatedSecondsLeft: nil
                        )
                    )
                }
            }
        }

        progress(
            ScanProgress(
                percent: 1.0,
                currentTask: "Mail scan complete",
                currentPath: "",
                filesScanned: filesScanned,
                bytesFoundSoFar: bytesFound,
                estimatedSecondsLeft: 0
            )
        )
        return results
    }
}
