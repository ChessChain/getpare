// App/Sources/Utilities/DuplicateDetector.swift
//
// Hash-based duplicate file detection using SHA256.
// Groups files by size first (fast), then hashes only same-size files.

import Foundation
import CryptoKit

public struct DuplicateGroup: Identifiable {
    public let id: String          // hash
    public let hash: String
    public let fileName: String    // representative name
    public let fileSize: Int64
    public let sizeLabel: String
    public var files: [DuplicateFile]

    public var savingsBytes: Int64 { fileSize * Int64(max(0, files.count - 1)) }
    public var savingsLabel: String { ByteCountFormatter.string(fromByteCount: savingsBytes, countStyle: .file) }
}

public struct DuplicateFile: Identifiable, Hashable {
    public let id: String  // path
    public let url: URL
    public let path: String
    public let isKeep: Bool  // the one Pare recommends keeping
    public var isSelected: Bool
}

public final class DuplicateDetector {

    public struct ScanResult {
        public let groups: [DuplicateGroup]
        public let totalFiles: Int
        public let totalSavings: Int64
        public let scannedFiles: Int
    }

    /// Scan directories for duplicate files using size + SHA256 hash
    public static func scan(
        directories: [URL],
        minSize: Int64 = 10_000,  // ignore files < 10 KB
        progress: ((String, Double) -> Void)? = nil
    ) -> ScanResult {
        let fm = FileManager.default

        // Phase 1: Group files by size (very fast)
        progress?("Indexing files by size...", 0.05)
        var sizeMap: [Int64: [URL]] = [:]
        var totalScanned = 0

        for dir in directories {
            guard let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      values.isRegularFile == true else { continue }
                let size = Int64(values.fileSize ?? 0)
                guard size >= minSize else { continue }
                totalScanned += 1
                sizeMap[size, default: []].append(fileURL)
            }
        }

        // Filter to only sizes with 2+ files (potential duplicates)
        let candidates = sizeMap.filter { $0.value.count >= 2 }
        progress?("Found \(candidates.count) size groups to hash...", 0.3)

        // Phase 2: Hash files within each size group
        var hashMap: [String: [URL]] = [:]
        let totalCandidateGroups = candidates.count
        var processed = 0

        for (_, files) in candidates {
            processed += 1
            if processed % 10 == 0 {
                let pct = 0.3 + 0.6 * Double(processed) / Double(totalCandidateGroups)
                progress?("Hashing group \(processed)/\(totalCandidateGroups)...", pct)
            }

            for fileURL in files {
                if let hash = hashFile(fileURL) {
                    hashMap[hash, default: []].append(fileURL)
                }
            }
        }

        // Phase 3: Build groups from hash matches
        progress?("Building duplicate groups...", 0.95)
        var groups: [DuplicateGroup] = []
        let home = fm.homeDirectoryForCurrentUser

        for (hash, files) in hashMap where files.count >= 2 {
            let size = (try? files[0].resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
            let name = files[0].lastPathComponent

            // Pick the "keep" file — prefer the one in Documents or the most recent
            let sorted = files.sorted { f1, f2 in
                let d1 = (try? f1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? f2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2  // newest first
            }

            let dupeFiles = sorted.enumerated().map { (idx, url) -> DuplicateFile in
                DuplicateFile(
                    id: url.path,
                    url: url,
                    path: url.path.replacingOccurrences(of: home.path, with: "~"),
                    isKeep: idx == 0,
                    isSelected: idx > 0  // select all except the keeper
                )
            }

            groups.append(DuplicateGroup(
                id: hash,
                hash: String(hash.prefix(12)),
                fileName: name,
                fileSize: size,
                sizeLabel: ByteCountFormatter.string(fromByteCount: size, countStyle: .file),
                files: dupeFiles
            ))
        }

        groups.sort { $0.savingsBytes > $1.savingsBytes }

        let totalSavings = groups.reduce(Int64(0)) { $0 + $1.savingsBytes }
        let totalDupes = groups.reduce(0) { $0 + $1.files.count }

        progress?("Complete", 1.0)
        return ScanResult(groups: groups, totalFiles: totalDupes, totalSavings: totalSavings, scannedFiles: totalScanned)
    }

    // MARK: - SHA256 Hash (first 64KB + last 64KB for speed)

    private static func hashFile(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }

        var hasher = SHA256()

        // Read first 64 KB
        let headData = handle.readData(ofLength: 65536)
        hasher.update(data: headData)

        // Seek to end - 64 KB for tail hash (fast duplicate detection)
        let fileSize = handle.seekToEndOfFile()
        if fileSize > 131072 {
            handle.seek(toFileOffset: fileSize - 65536)
            let tailData = handle.readData(ofLength: 65536)
            hasher.update(data: tailData)
        }

        // Include file size in hash to avoid false positives
        var sizeBytes = fileSize
        hasher.update(data: Data(bytes: &sizeBytes, count: 8))

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
