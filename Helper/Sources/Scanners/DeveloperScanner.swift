// Helper/Sources/Scanners/DeveloperScanner.swift
//
// FR-09 — Xcode build artefacts. Walks the well-known safe-to-clear roots:
//   - ~/Library/Developer/Xcode/DerivedData/      (pure build output)
//   - ~/Library/Developer/CoreSimulator/Caches/   (simulator caches)
//   - ~/Library/Caches/com.apple.dt.Xcode/         (Xcode app cache)
//
// Deliberately out of scope for this iteration, even though the BRD lists
// them: ~/Library/Developer/Xcode/Archives (irreplaceable distribution
// archives) and the simulator devices themselves (the user's active
// workspace). Node `node_modules` detection also stays in the TODO list —
// it needs a presence-of-package-lock heuristic to be safe.

import Foundation
import PareKit

public struct DeveloperScanner: Scanner {
    public let category: PareKit.Category = .developerJunk

    public let roots: [URL]
    public let progressEveryNFiles: Int

    public init(roots: [URL]? = nil, progressEveryNFiles: Int = 500) {
        self.roots = roots ?? Self.defaultRoots()
        self.progressEveryNFiles = max(1, progressEveryNFiles)
    }

    private static func defaultRoots() -> [URL] {
        let home = URL(fileURLWithPath: ProtectedPaths.currentUserHome())
        return [
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
            home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
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

                let pathLower = url.path.lowercased()
                let subcategory: String
                if pathLower.contains("/deriveddata/") {
                    subcategory = "deriveddata"
                } else if pathLower.contains("/coresimulator/") {
                    subcategory = "simulator-cache"
                } else if pathLower.contains("/com.apple.dt.xcode/") {
                    subcategory = "xcode-cache"
                } else {
                    subcategory = "other"
                }

                results.append(
                    ScanItem(
                        path: url,
                        category: .developerJunk,
                        bytes: size,
                        lastModified: modified,
                        lastAccessed: accessed,
                        riskLevel: .safe,
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
                            currentTask: "Scanning Xcode build artefacts",
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
                currentTask: "Developer scan complete",
                currentPath: "",
                filesScanned: filesScanned,
                bytesFoundSoFar: bytesFound,
                estimatedSecondsLeft: 0
            )
        )
        return results
    }
}
