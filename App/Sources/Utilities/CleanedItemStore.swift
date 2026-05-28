// App/Sources/Utilities/CleanedItemStore.swift
//
// Moves files to ~/Library/Application Support/Pare/RecoveryBin/
// and tracks them in a JSON manifest. Supports restore and auto-purge.

import Foundation
import Combine

final class CleanedItemStore: ObservableObject {
    static let shared = CleanedItemStore()

    struct CleanedItem: Codable, Identifiable {
        let id: String
        let fileName: String
        let originalPath: String
        let archivedPath: String   // path inside recovery bin
        let category: String
        let bytes: Int64
        let cleanedDate: Date

        var daysLeft: Int {
            max(0, 30 - Int(-cleanedDate.timeIntervalSinceNow / 86400))
        }

        var sizeLabel: String {
            ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        var metaLabel: String {
            let days = Int(-cleanedDate.timeIntervalSinceNow / 86400)
            let ago: String
            if days == 0 { ago = "today" }
            else if days == 1 { ago = "yesterday" }
            else { ago = "\(days) days ago" }
            return "\(sizeLabel) \u{00B7} removed \(ago)"
        }
    }

    @Published var items: [CleanedItem] = []

    var totalCount: Int { items.count }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    var totalSizeLabel: String { ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file) }

    var daysLabel: String {
        guard let oldest = items.min(by: { $0.cleanedDate < $1.cleanedDate }) else { return "empty" }
        return "\(oldest.daysLeft) days"
    }

    private let supportDir: URL
    private let binDir: URL
    private let manifestURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        supportDir = home.appendingPathComponent("Library/Application Support/Pare")
        binDir = supportDir.appendingPathComponent("RecoveryBin")
        manifestURL = supportDir.appendingPathComponent("recovery_manifest.json")

        try? FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        load()
        // Auto-purge expired items
        let expired = items.filter { $0.daysLeft <= 0 }
        for item in expired {
            try? FileManager.default.removeItem(atPath: item.archivedPath)
        }
        items.removeAll { $0.daysLeft <= 0 }
        save()
    }

    /// Move a file to the recovery bin. Returns true on success.
    func moveToRecoveryBin(url: URL, fileName: String, originalPath: String, category: String, bytes: Int64) -> Bool {
        let fm = FileManager.default
        let uniqueName = "\(UUID().uuidString)_\(fileName)"
        let dest = binDir.appendingPathComponent(uniqueName)

        do {
            if fm.fileExists(atPath: url.path) {
                try fm.moveItem(at: url, to: dest)
            } else {
                return false
            }
        } catch {
            // If move fails (cross-volume, permissions), try copy+delete
            do {
                try fm.copyItem(at: url, to: dest)
                try fm.removeItem(at: url)
            } catch {
                // Last resort: just delete without archiving
                do {
                    try fm.removeItem(at: url)
                } catch {
                    return false
                }
                // Record without archive path
                let item = CleanedItem(
                    id: UUID().uuidString, fileName: fileName,
                    originalPath: originalPath, archivedPath: "",
                    category: category, bytes: bytes, cleanedDate: Date()
                )
                items.insert(item, at: 0)
                save()
                return true
            }
        }

        let item = CleanedItem(
            id: UUID().uuidString, fileName: fileName,
            originalPath: originalPath, archivedPath: dest.path,
            category: category, bytes: bytes, cleanedDate: Date()
        )
        items.insert(item, at: 0)
        save()
        return true
    }

    /// Add items that were deleted without archiving (e.g. from Uninstaller)
    func addBatch(_ entries: [(fileName: String, path: String, category: String, bytes: Int64)]) {
        for entry in entries {
            items.insert(CleanedItem(
                id: UUID().uuidString, fileName: entry.fileName,
                originalPath: entry.path, archivedPath: "",
                category: entry.category, bytes: entry.bytes, cleanedDate: Date()
            ), at: 0)
        }
        save()
    }

    /// Restore a file from the recovery bin to its original location
    func restore(id: String) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let fm = FileManager.default

        if !item.archivedPath.isEmpty && fm.fileExists(atPath: item.archivedPath) {
            // Reconstruct original path from the tilde-expanded path
            let home = fm.homeDirectoryForCurrentUser.path
            let origPath = item.originalPath.replacingOccurrences(of: "~", with: home)
            let origURL = URL(fileURLWithPath: origPath)

            // Ensure parent directory exists
            try? fm.createDirectory(at: origURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            do {
                try fm.moveItem(atPath: item.archivedPath, toPath: origURL.path)
            } catch {
                // If restore fails, at least move to Desktop
                let desktop = fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(item.fileName)")
                try? fm.moveItem(atPath: item.archivedPath, toPath: desktop.path)
            }
        }

        items.removeAll { $0.id == id }
        save()
    }

    /// Permanently delete a single item from the bin
    func permanentlyDelete(id: String) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        if !item.archivedPath.isEmpty {
            try? FileManager.default.removeItem(atPath: item.archivedPath)
        }
        items.removeAll { $0.id == id }
        save()
    }

    func removeAll() {
        for item in items {
            if !item.archivedPath.isEmpty {
                try? FileManager.default.removeItem(atPath: item.archivedPath)
            }
        }
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([CleanedItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }
}
