// App/Sources/Views/SpaceLens/SpaceLensViewModel.swift
// v0.8 — Two-pane file browser with back/forward navigation

import Foundation
import SwiftUI

struct LensEntry: Identifiable {
    let id: String
    let name: String
    let url: URL
    let bytes: Int64
    let sizeLabel: String
    let isDirectory: Bool
    let isProtected: Bool
    let childCount: Int
}

struct BreadcrumbItem {
    let name: String
    let url: URL
}

public final class SpaceLensViewModel: ObservableObject {
    @Published var entries: [LensEntry] = []
    @Published var breadcrumbs: [BreadcrumbItem] = []
    @Published var isLoading = false
    @Published var selectedId: String? = nil

    private var history: [URL] = []
    private var historyIndex = -1

    var currentName: String { breadcrumbs.last?.name ?? "Macintosh HD" }
    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < history.count - 1 }

    var selectedEntry: LensEntry? {
        guard let id = selectedId else { return nil }
        return entries.first { $0.id == id }
    }

    // Disk usage
    var diskUsageLabel: String {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free = (attrs[.systemFreeSize] as? Int64) ?? 0
            let used = total - free
            return "\(used / 1_073_741_824) GB of \(total / 1_073_741_824) GB used"
        }
        return ""
    }

    var diskUsagePercent: CGFloat {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? Int64) ?? 1
            let free = (attrs[.systemFreeSize] as? Int64) ?? 0
            return CGFloat(total - free) / CGFloat(total)
        }
        return 0.5
    }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        navigateTo(home, addToHistory: true)
    }

    // MARK: - Navigation

    func drillInto(_ entry: LensEntry) {
        guard entry.isDirectory else { return }
        navigateTo(entry.url, addToHistory: true)
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        navigateTo(history[historyIndex], addToHistory: false)
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        navigateTo(history[historyIndex], addToHistory: false)
    }

    func navigateToCrumb(_ index: Int) {
        guard index < breadcrumbs.count else { return }
        navigateTo(breadcrumbs[index].url, addToHistory: true)
    }

    func loadCurrentDirectory() {
        if let last = breadcrumbs.last {
            loadDirectory(last.url)
        }
    }

    private func navigateTo(_ url: URL, addToHistory: Bool) {
        selectedId = nil

        // Build breadcrumbs from root to url
        let home = FileManager.default.homeDirectoryForCurrentUser
        var crumbs: [BreadcrumbItem] = []
        var current = url
        var parts: [(String, URL)] = []

        while current.path != "/" {
            let name = current.lastPathComponent
            let display = current.path == home.path ? "~" : name
            parts.insert((display, current), at: 0)
            current = current.deletingLastPathComponent()
        }
        parts.insert(("Macintosh HD", URL(fileURLWithPath: "/")), at: 0)

        // Simplify: show disk + relative from home
        if let homeIdx = parts.firstIndex(where: { $0.1.path == home.path }) {
            crumbs.append(BreadcrumbItem(name: "Macintosh HD", url: URL(fileURLWithPath: "/")))
            for i in homeIdx..<parts.count {
                crumbs.append(BreadcrumbItem(name: parts[i].0, url: parts[i].1))
            }
        } else {
            crumbs = parts.map { BreadcrumbItem(name: $0.0, url: $0.1) }
        }

        breadcrumbs = crumbs

        if addToHistory {
            // Trim forward history
            if historyIndex < history.count - 1 {
                history = Array(history.prefix(historyIndex + 1))
            }
            history.append(url)
            historyIndex = history.count - 1
        }

        loadDirectory(url)
    }

    private var loadGeneration = 0

    private func loadDirectory(_ url: URL) {
        isLoading = true
        entries = []
        loadGeneration += 1
        let gen = loadGeneration
        let vm = self

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default

            guard let contents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .totalFileAllocatedSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                DispatchQueue.main.async { vm.isLoading = false }
                return
            }

            // Phase 1: show items instantly with file sizes (dirs show 0 initially)
            var items: [LensEntry] = []
            for item in contents {
                guard gen == vm.loadGeneration else { return } // cancelled
                let values = try? item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .totalFileAllocatedSizeKey])
                let isDir = values?.isDirectory ?? false
                let fileBytes = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
                let bytes: Int64 = isDir ? 0 : fileBytes
                let childCount: Int
                if isDir {
                    childCount = (try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).count) ?? 0
                } else {
                    childCount = 0
                }

                let path = item.path
                let isProtected = path.contains("/System/") || path.contains("/.") || !fm.isDeletableFile(atPath: path)

                items.append(LensEntry(
                    id: item.path, name: item.lastPathComponent, url: item,
                    bytes: bytes, sizeLabel: isDir ? "..." : Self.fmt(bytes),
                    isDirectory: isDir, isProtected: isProtected, childCount: childCount
                ))
            }

            // Sort files by size, dirs first (will re-sort after sizes load)
            items.sort { ($0.isDirectory ? 1 : 0, $1.bytes) > ($1.isDirectory ? 1 : 0, $0.bytes) }

            DispatchQueue.main.async {
                guard gen == vm.loadGeneration else { return }
                vm.entries = items
                vm.isLoading = false
            }

            // Phase 2: calculate directory sizes progressively
            let dirs = items.filter(\.isDirectory)
            for dir in dirs {
                guard gen == vm.loadGeneration else { return } // cancelled by new navigation
                let size = SystemStorageProvider.directorySize(dir.url)
                DispatchQueue.main.async {
                    guard gen == vm.loadGeneration else { return }
                    if let idx = vm.entries.firstIndex(where: { $0.id == dir.id }) {
                        vm.entries[idx] = LensEntry(
                            id: dir.id, name: dir.name, url: dir.url,
                            bytes: size, sizeLabel: Self.fmt(size),
                            isDirectory: true, isProtected: dir.isProtected, childCount: dir.childCount
                        )
                    }
                    // Re-sort after each update
                    vm.entries.sort { $0.bytes > $1.bytes }
                }
            }
        }
    }

    static func fmt(_ b: Int64) -> String {
        let gb = Double(b) / 1_073_741_824.0
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        let mb = Double(b) / 1_000_000.0
        if mb >= 1.0 { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(b) / 1_000.0)
    }
}
