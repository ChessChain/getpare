// Helper/Sources/Scanners/LargeFileScanner.swift
//
// FR-04 — files above `options.largeFileThresholdBytes`. Walks the user's
// home and media directories, skipping protected paths and bundle contents.
// Yields to Task.checkCancellation() every iteration so user-initiated
// cancel feels instant.

import Foundation
import PareKit

public struct LargeFileScanner: Scanner {
    public let category: PareKit.Category = .largeFile

    /// Directories to walk. Defaults to the console user's main home folders.
    /// Injectable so HelperTests can run against a temp directory tree.
    public let roots: [URL]

    /// Emit a progress event every N files visited. Lower = smoother UI, more XPC chatter.
    public let progressEveryNFiles: Int

    public init(roots: [URL]? = nil, progressEveryNFiles: Int = 500) {
        self.roots = roots ?? Self.defaultRoots()
        self.progressEveryNFiles = max(1, progressEveryNFiles)
    }

    private static func defaultRoots() -> [URL] {
        let home = URL(fileURLWithPath: ProtectedPaths.currentUserHome())
        return [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Music"),
            home.appendingPathComponent("Pictures"),
        ]
    }

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        let threshold = options.largeFileThresholdBytes
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
                    let rawSize = values.fileSize
                else { continue }

                let size = Int64(rawSize)
                guard size >= threshold else { continue }

                results.append(
                    ScanItem(
                        path: url,
                        category: .largeFile,
                        bytes: size,
                        lastModified: values.contentModificationDate ?? Date.distantPast,
                        lastAccessed: values.contentAccessDate ?? Date.distantPast,
                        riskLevel: .caution,
                        metadata: [
                            "ext": url.pathExtension,
                            "filename": url.lastPathComponent,
                        ]
                    )
                )
                bytesFound += size

                if filesScanned % progressEveryNFiles == 0 {
                    progress(
                        ScanProgress(
                            percent: Double(rootIdx) / Double(totalRoots),
                            currentTask: "Scanning large files",
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
                currentTask: "Large file scan complete",
                currentPath: "",
                filesScanned: filesScanned,
                bytesFoundSoFar: bytesFound,
                estimatedSecondsLeft: 0
            )
        )
        return results
    }
}
