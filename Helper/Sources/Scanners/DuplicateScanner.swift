// Helper/Sources/Scanners/DuplicateScanner.swift
//
// FR-05 — duplicate detection. Two-pass per ADR-0005:
//   1. Walk roots, gather candidates ≥ minSize, bucket by file size.
//   2. For every size bucket with >1 file, hash each candidate
//      (SHA-256; BLAKE3 for >100MB is still TODO in HashIndex).
// Files sharing a hash are grouped; the oldest by content-mod date wins
// the "canonical" slot, every other file in the group is emitted as a
// duplicate ScanItem the user can safely delete.

import Foundation
import PareKit

public struct DuplicateScanner: Scanner {
    public let category: PareKit.Category = .duplicate

    public let roots: [URL]
    /// Files smaller than this are ignored — hashing tiny files is rarely
    /// worth the I/O and noise. Default 4 KB.
    public let minSize: Int64
    public let progressEveryNFiles: Int

    public init(roots: [URL]? = nil, minSize: Int64 = 4_096, progressEveryNFiles: Int = 200) {
        self.roots = roots ?? Self.defaultRoots()
        self.minSize = max(0, minSize)
        self.progressEveryNFiles = max(1, progressEveryNFiles)
    }

    private static func defaultRoots() -> [URL] {
        let home = URL(fileURLWithPath: ProtectedPaths.currentUserHome())
        return [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Pictures"),
        ]
    }

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        // ── Pass 1: gather candidates and bucket by size ────────────────
        let candidates = try await gatherCandidates(progress: progress)
        let sizeBuckets = Dictionary(grouping: candidates, by: { $0.bytes })
            .filter { $0.value.count > 1 }

        // ── Pass 2: hash within each multi-file size bucket ─────────────
        progress(
            ScanProgress(
                percent: 0.5,
                currentTask: "Hashing candidates",
                currentPath: "",
                filesScanned: candidates.count,
                bytesFoundSoFar: 0,
                estimatedSecondsLeft: nil
            )
        )

        var byHash: [String: [Candidate]] = [:]
        var hashed = 0
        let totalToHash = sizeBuckets.values.reduce(0) { $0 + $1.count }

        for (_, bucket) in sizeBuckets {
            for cand in bucket {
                try Task.checkCancellation()
                guard let digest = try? await HashIndex.hash(cand.url) else { continue }
                byHash[digest, default: []].append(cand)

                hashed += 1
                if hashed % progressEveryNFiles == 0 {
                    let pct = totalToHash > 0
                        ? 0.5 + 0.5 * (Double(hashed) / Double(totalToHash))
                        : 1.0
                    progress(
                        ScanProgress(
                            percent: min(0.99, pct),
                            currentTask: "Hashing \(hashed)/\(totalToHash)",
                            currentPath: cand.url.path,
                            filesScanned: candidates.count,
                            bytesFoundSoFar: 0,
                            estimatedSecondsLeft: nil
                        )
                    )
                }
            }
        }

        // ── Emit duplicates ─────────────────────────────────────────────
        var results: [ScanItem] = []
        var totalDupeBytes: Int64 = 0

        for (digest, group) in byHash where group.count > 1 {
            let groupID = UUID()
            let sorted = group.sorted { $0.modified < $1.modified }
            guard let canonical = sorted.first else { continue }

            for cand in sorted.dropFirst() {
                results.append(
                    ScanItem(
                        path: cand.url,
                        category: .duplicate,
                        bytes: cand.bytes,
                        lastModified: cand.modified,
                        lastAccessed: cand.accessed,
                        contentHash: digest,
                        riskLevel: .safe,
                        groupID: groupID,
                        metadata: [
                            "canonical_path": canonical.url.path,
                            "group_size": "\(group.count)",
                            "filename": cand.url.lastPathComponent,
                        ]
                    )
                )
                totalDupeBytes += cand.bytes
            }
        }

        progress(
            ScanProgress(
                percent: 1.0,
                currentTask: "Duplicate scan complete",
                currentPath: "",
                filesScanned: candidates.count,
                bytesFoundSoFar: totalDupeBytes,
                estimatedSecondsLeft: 0
            )
        )
        return results
    }

    // MARK: - Pass 1

    private struct Candidate: Sendable {
        let url: URL
        let bytes: Int64
        let modified: Date
        let accessed: Date
    }

    private func gatherCandidates(
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [Candidate] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .isRegularFileKey,
            .contentModificationDateKey,
            .contentAccessDateKey,
        ]
        let totalRoots = max(1, roots.count)
        var candidates: [Candidate] = []
        var filesScanned = 0

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
                guard size >= minSize else { continue }

                candidates.append(
                    Candidate(
                        url: url,
                        bytes: size,
                        modified: values.contentModificationDate ?? Date.distantPast,
                        accessed: values.contentAccessDate ?? Date.distantPast
                    )
                )

                if filesScanned % progressEveryNFiles == 0 {
                    let pct = 0.5 * (Double(rootIdx) + 1.0) / Double(totalRoots)
                    progress(
                        ScanProgress(
                            percent: min(0.49, pct),
                            currentTask: "Gathering files for duplicate analysis",
                            currentPath: url.path,
                            filesScanned: filesScanned,
                            bytesFoundSoFar: 0,
                            estimatedSecondsLeft: nil
                        )
                    )
                }
            }
        }
        return candidates
    }
}
