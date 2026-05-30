// App/Sources/Utilities/SystemStorageProvider.swift
//
// Reads real disk capacity, usage, and per-directory sizes from the system.

import Foundation

public struct StorageSnapshot {
    public let totalCapacity: Int64
    public let availableBytes: Int64
    public var usedBytes: Int64 { totalCapacity - availableBytes }

    public let applicationsBytes: Int64
    public let documentsBytes: Int64
    public let mediaBytes: Int64
    public let developerBytes: Int64
    public let downloadsBytes: Int64
    public let libraryBytes: Int64
    public let systemBytes: Int64

    public let userName: String
}

public enum SystemStorageProvider {

    public static func snapshot() -> StorageSnapshot {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // Volume stats — FileManager.attributesOfFileSystem is the most reliable
        let (total, available) = volumeStats()

        // Per-directory sizes (best-effort, skips inaccessible paths)
        let apps        = directorySize(URL(fileURLWithPath: "/Applications")) +
                          directorySize(home.appendingPathComponent("Applications"))
        let documents   = directorySize(home.appendingPathComponent("Documents"))
        let downloads   = directorySize(home.appendingPathComponent("Downloads"))
        let movies      = directorySize(home.appendingPathComponent("Movies"))
        let music       = directorySize(home.appendingPathComponent("Music"))
        let pictures    = directorySize(home.appendingPathComponent("Pictures"))
        let developer   = directorySize(home.appendingPathComponent("Library/Developer"))
        let library     = directorySize(home.appendingPathComponent("Library"))

        let media = movies + music + pictures
        let knownUser = apps + documents + downloads + media + developer
        let used = total - available
        let system = max(0, used - knownUser)

        let userName = NSFullUserName().components(separatedBy: " ").first ?? "User"

        return StorageSnapshot(
            totalCapacity: total,
            availableBytes: available,
            applicationsBytes: apps,
            documentsBytes: documents,
            mediaBytes: media,
            developerBytes: developer,
            downloadsBytes: downloads,
            libraryBytes: library,
            systemBytes: system,
            userName: userName
        )
    }

    // MARK: - Volume Stats

    private static func volumeStats() -> (total: Int64, available: Int64) {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free  = (attrs[.systemFreeSize] as? Int64) ?? 0
            return (total, free)
        } catch {
            return (0, 0)
        }
    }

    // MARK: - Directory Size

    /// Recursive directory size. Skips directories it cannot read.
    static func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return 0 }
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true } // skip errors, continue
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    // MARK: - Reclaimable Estimate

    public static func estimateReclaimable() -> Int64 {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let paths = [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Developer"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Library/Mail"),
        ]
        return paths.reduce(Int64(0)) { $0 + directorySize($1) }
    }

    // MARK: - Category Sizes

    public struct CategorySizes {
        public let systemJunk: Int64
        public let duplicates: Int64
        public let largeFiles: Int64
        public let downloads: Int64
        public let photos: Int64
        public let uninstaller: Int64
        public let mail: Int64
        public let developer: Int64
    }

    public static func categorySizes() -> CategorySizes {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let downloads = directorySize(home.appendingPathComponent("Downloads"))

        // Large files: count files > 100 MB in Downloads, Documents, Movies
        var largeFilesTotal: Int64 = 0
        for dir in [home.appendingPathComponent("Downloads"), home.appendingPathComponent("Documents"), home.appendingPathComponent("Movies")] {
            if let en = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsPackageDescendants, .skipsHiddenFiles], errorHandler: { _, _ in true }) {
                for case let f as URL in en {
                    if let v = try? f.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                       v.isRegularFile == true, let size = v.fileSize, size > 100_000_000 {
                        largeFilesTotal += Int64(size)
                    }
                }
            }
        }

        // Duplicates: estimate by scanning Downloads for files with similar sizes (rough heuristic)
        var duplicatesTotal: Int64 = 0
        var sizeMap: [Int64: Int] = [:]
        if let en = fm.enumerator(at: home.appendingPathComponent("Downloads"), includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles], errorHandler: { _, _ in true }) {
            for case let f as URL in en {
                if let v = try? f.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                   v.isRegularFile == true, let size = v.fileSize, size > 10_000 {
                    let key = Int64(size)
                    sizeMap[key, default: 0] += 1
                    if sizeMap[key]! > 1 { duplicatesTotal += key }
                }
            }
        }

        return CategorySizes(
            systemJunk: directorySize(home.appendingPathComponent("Library/Caches")) +
                        directorySize(home.appendingPathComponent("Library/Logs")),
            duplicates: duplicatesTotal,
            largeFiles: largeFilesTotal,
            downloads:  downloads,
            photos:     directorySize(home.appendingPathComponent("Pictures")),
            uninstaller: directorySize(URL(fileURLWithPath: "/Applications")),
            mail:       directorySize(home.appendingPathComponent("Library/Mail")),
            developer:  directorySize(home.appendingPathComponent("Library/Developer"))
        )
    }
}
