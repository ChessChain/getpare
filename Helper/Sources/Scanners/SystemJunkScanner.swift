// Helper/Sources/Scanners/SystemJunkScanner.swift
//
// FR-03 — user-space caches and logs. Walks the conventional safe-to-clear
// directories (`~/Library/Caches`, `~/Library/Logs`). Each file is tagged
// `.safe` if its content-access date is older than seven days, otherwise
// `.caution` because the owning app may still be holding it open.
//
// Deliberately out of scope for this iteration:
//   - language `.lproj` pruning (risky without locale-aware safety net)
//   - broken-preferences detection (requires plist parsing + heuristics)
// Both items are tracked in the BRD; revisit before public v1.0.

import Foundation
import PareKit

public struct SystemJunkScanner: Scanner {
    public let category: PareKit.Category = .systemJunk

    /// Directories to walk. Injectable so HelperTests can drive it against
    /// a temp tree without touching the real ~/Library.
    public let roots: [URL]
    public let progressEveryNFiles: Int

    public init(roots: [URL]? = nil, progressEveryNFiles: Int = 500) {
        self.roots = roots ?? Self.defaultRoots()
        self.progressEveryNFiles = max(1, progressEveryNFiles)
    }

    private static func defaultRoots() -> [URL] {
        let home = URL(fileURLWithPath: ProtectedPaths.currentUserHome())
        return [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Logs"),
        ]
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

                guard
                    let values = try? url.resourceValues(forKeys: Set(keys)),
                    values.isRegularFile == true,
                    let rawSize = values.fileSize,
                    rawSize > 0
                else { continue }

                let size = Int64(rawSize)
                let modified = values.contentModificationDate ?? Date.distantPast
                let accessed = values.contentAccessDate ?? modified
                let ageInDays = -accessed.timeIntervalSinceNow / 86_400
                let risk: Risk = ageInDays > 7 ? .safe : .caution

                let pathLower = url.path.lowercased()
                let subcategory: String
                if pathLower.contains("/library/caches/") {
                    subcategory = "cache"
                } else if pathLower.contains("/library/logs/") {
                    subcategory = "log"
                } else {
                    subcategory = "other"
                }

                results.append(
                    ScanItem(
                        path: url,
                        category: .systemJunk,
                        bytes: size,
                        lastModified: modified,
                        lastAccessed: accessed,
                        riskLevel: risk,
                        metadata: [
                            "subcategory": subcategory,
                            "filename": url.lastPathComponent,
                        ]
                    )
                )
                bytesFound += size

                if filesScanned % progressEveryNFiles == 0 {
                    progress(
                        ScanProgress(
                            percent: Double(rootIdx) / Double(totalRoots),
                            currentTask: "Scanning caches & logs",
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
                currentTask: "System junk scan complete",
                currentPath: "",
                filesScanned: filesScanned,
                bytesFoundSoFar: bytesFound,
                estimatedSecondsLeft: 0
            )
        )
        return results
    }
}
