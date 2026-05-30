// App/Sources/Views/Categories/CategoryDetailViewModel.swift

import Foundation
import SwiftUI
import PareKit

struct CategoryItem: Identifiable {
    let id: String
    let name: String
    let detail: String
    let thumbLabel: String
    let typeLabel: String
    let filterTag: String   // used for filtering
    let lastTouched: String
    let sizeLabel: String
    let bytes: Int64
    var isSelected: Bool
    let isProtected: Bool
    let url: URL
}

struct SummaryCard: Identifiable {
    let id: String
    let label: String
    var value: String
    let isAccent: Bool
}

final class CategoryDetailViewModel: ObservableObject {
    let category: CategoryType

    @Published var allItems: [CategoryItem] = []  // full unfiltered list
    @Published var items: [CategoryItem] = []     // filtered display list
    @Published var summaryCards: [SummaryCard] = []
    @Published var isLoading = true
    @Published var scanProgress: Double = 0
    @Published var scanTask: String = "Preparing..."
    @Published var activeFilter: String = "All" {
        didSet { applyFilter() }
    }
    @Published var searchQuery: String = "" {
        didSet { applyFilter() }
    }

    // Confirm modal
    @Published var showConfirm = false
    @Published var showSuccess = false
    @Published var showPaywall = false
    @Published var cleanedCount = 0
    @Published var cleanedSize: Int64 = 0

    /// True when scanning is running directly in the App rather than via the
    /// privileged helper — i.e. no FDA, limited visibility into TCC-protected
    /// paths. UI surfaces a small banner so the user knows.
    @Published var isLimitedMode: Bool = false

    var filters: [String] { category.filters }

    var selectedCount: Int { items.filter(\.isSelected).count }
    var selectedBytes: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.bytes } }
    var selectedSizeLabel: String { Self.fmt(selectedBytes) }

    init(category: CategoryType) {
        self.category = category
        loadItems()
    }

    // MARK: - Actions

    func toggleItem(_ id: String) {
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].isSelected.toggle()
        }
        if let i = allItems.firstIndex(where: { $0.id == id }) {
            allItems[i].isSelected.toggle()
        }
    }

    func deselectAll() {
        for i in items.indices { items[i].isSelected = false }
        for i in allItems.indices { allItems[i].isSelected = false }
    }

    func selectAll() {
        for i in items.indices where !items[i].isProtected { items[i].isSelected = true }
        let ids = Set(items.filter(\.isSelected).map(\.id))
        for i in allItems.indices where ids.contains(allItems[i].id) { allItems[i].isSelected = true }
    }

    func reviewAndClean() {
        guard selectedCount > 0 else { return }
        // Check free limit
        let licence = LicenceManager.shared
        if licence.wouldExceedLimit(bytes: selectedBytes) {
            showPaywall = true
            return
        }
        showConfirm = true
    }

    func confirmClean() {
        showConfirm = false
        let toClean = items.filter(\.isSelected)
        cleanedCount = 0
        cleanedSize = 0

        let store = CleanedItemStore.shared
        var successIds: Set<String> = []

        for item in toClean {
            // Final safety check — skip protected or undeletable files
            guard !item.isProtected else { continue }
            guard FileManager.default.isDeletableFile(atPath: item.url.path) else { continue }
            guard FileManager.default.fileExists(atPath: item.url.path) else { continue }

            let moved = store.moveToRecoveryBin(
                url: item.url,
                fileName: item.name,
                originalPath: item.detail,
                category: category.title,
                bytes: item.bytes
            )
            if moved {
                successIds.insert(item.id)
                cleanedCount += 1
                cleanedSize += item.bytes
            }
        }

        // Record usage
        LicenceManager.shared.recordCleanup(bytes: cleanedSize)

        // Remove cleaned items from list
        allItems.removeAll { successIds.contains($0.id) }
        applyFilter()
        showSuccess = cleanedCount > 0
    }

    func cancelClean() {
        showConfirm = false
    }

    // MARK: - Filtering

    private func applyFilter() {
        var filtered: [CategoryItem]
        if activeFilter == "All" {
            filtered = allItems
        } else {
            filtered = allItems.filter { $0.filterTag.localizedCaseInsensitiveContains(activeFilter) }
        }
        // Apply search
        if !searchQuery.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) || $0.detail.localizedCaseInsensitiveContains(searchQuery) }
        }
        items = filtered
    }


    // MARK: - Load real items

    private func loadItems() {
        if let helperCategory = Self.helperCategory(for: category) {
            Task { @MainActor in
                let handled = await self.loadViaHelper(helperCategory: helperCategory)
                if !handled {
                    self.isLimitedMode = true
                    self.loadItemsLocally()
                }
            }
            return
        }
        // Categories without a helper-side scanner stay on the direct-FS path.
        isLimitedMode = true
        loadItemsLocally()
    }

    /// Returns the helper-side category that backs a UI category, or nil if
    /// no helper scanner exists yet (in which case we use the local walker).
    private static func helperCategory(for category: CategoryType) -> PareKit.Category? {
        switch category {
        case .largeFiles:    return .largeFile
        case .systemJunk:    return .systemJunk
        case .duplicates:    return .duplicate
        case .mailCleanup:   return .mailCache
        case .developerJunk: return .developerJunk
        default:             return nil
        }
    }

    /// Try the helper for this view's category. Returns false when the
    /// helper is unavailable or errored — caller must fall back to local.
    @MainActor
    private func loadViaHelper(helperCategory: PareKit.Category) async -> Bool {
        let cat = category
        let vm = self
        let scanItems = await HelperScanRoute.fetch(categories: [helperCategory]) { progress in
            Task { @MainActor in
                vm.scanTask = progress.currentTask
                vm.scanProgress = progress.percent
            }
        }
        guard let scanItems = scanItems else { return false }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let mapped: [CategoryItem] = scanItems.map { item in
            let path = item.path.path
            let shortPath = path.replacingOccurrences(of: home, with: "~")
            let ext = item.path.pathExtension.lowercased()
            let isDeletable = FileManager.default.isDeletableFile(atPath: path)
            return CategoryItem(
                id: path,
                name: item.path.lastPathComponent,
                detail: shortPath,
                thumbLabel: Self.thumbLabel(ext),
                typeLabel: Self.typeLabel(ext, category: cat),
                filterTag: Self.filterTag(ext, path: shortPath, category: cat),
                lastTouched: Self.relativeDate(item.lastModified),
                sizeLabel: Self.fmt(item.bytes),
                bytes: item.bytes,
                isSelected: false,
                isProtected: !isDeletable,
                url: item.path
            )
        }
        .sorted { $0.bytes > $1.bytes }

        let display = Array(mapped.prefix(200))
        allItems = display
        items = display
        summaryCards = Self.buildSummary(
            cat,
            items: mapped,
            totalBytes: mapped.reduce(0) { $0 + $1.bytes }
        )
        scanProgress = 1.0
        scanTask = "Complete (via helper)"
        isLoading = false
        isLimitedMode = false
        return true
    }

    private func loadItemsLocally() {
        let cat = category
        let home = FileManager.default.homeDirectoryForCurrentUser
        let vm = self

        DispatchQueue.global(qos: .userInitiated).async {
            var allScanned: [CategoryItem] = []
            var totalBytes: Int64 = 0
            let targets = cat.scanPaths
            let totalTargets = targets.count

            for (idx, target) in targets.enumerated() {
                let url: URL
                if target.path.hasPrefix("/") {
                    url = URL(fileURLWithPath: target.path)
                } else {
                    url = home.appendingPathComponent(target.path)
                }

                DispatchQueue.main.async {
                    vm.scanTask = "Scanning \(target.label)..."
                    vm.scanProgress = Double(idx) / Double(totalTargets)
                }

                guard let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles],
                    errorHandler: { _, _ in true }
                ) else { continue }

                var count = 0
                for case let fileURL as URL in enumerator {
                    guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey, .isDirectoryKey]) else { continue }

                    let isDir = values.isDirectory ?? false
                    if isDir { continue }
                    guard values.isRegularFile == true else { continue }

                    let size = Int64(values.fileSize ?? 0)
                    if cat == .largeFiles && size < 100_000_000 { continue }
                    if cat == .duplicates && size < 10_000 { continue }  // duplicates: files > 10 KB
                    if size < 1_000 && cat != .systemJunk && cat != .duplicates { continue }

                    let path = fileURL.path
                    let shortPath = path.replacingOccurrences(of: home.path, with: "~")

                    // Safety: skip files that should never be cleaned
                    if Self.isProtectedPath(path) { continue }
                    if Self.isActivelyUsedFile(path) { continue }

                    // Only list files the user can actually delete
                    let isDeletable = FileManager.default.isDeletableFile(atPath: path)
                    let isProtected = !isDeletable || shortPath.contains("/System/")

                    totalBytes += size
                    count += 1
                    let modDate = values.contentModificationDate
                    let ago = Self.relativeDate(modDate)
                    let ext = fileURL.pathExtension.lowercased()

                    allScanned.append(CategoryItem(
                        id: path,
                        name: fileURL.lastPathComponent,
                        detail: shortPath,
                        thumbLabel: Self.thumbLabel(ext),
                        typeLabel: Self.typeLabel(ext, category: cat),
                        filterTag: Self.filterTag(ext, path: shortPath, category: cat),
                        lastTouched: ago,
                        sizeLabel: Self.fmt(size),
                        bytes: size,
                        isSelected: !isProtected && (cat == .systemJunk || cat == .mailCleanup),
                        isProtected: isProtected,
                        url: fileURL
                    ))

                    // Progress update every 200 files
                    if count % 200 == 0 {
                        let p = Double(idx) / Double(totalTargets) + (1.0 / Double(totalTargets)) * 0.5
                        DispatchQueue.main.async {
                            vm.scanProgress = min(0.95, p)
                        }
                    }
                }
            }

            allScanned.sort { $0.bytes > $1.bytes }
            let displayItems = Array(allScanned.prefix(200))
            let summaries = Self.buildSummary(cat, items: allScanned, totalBytes: totalBytes)

            DispatchQueue.main.async {
                vm.allItems = displayItems
                vm.items = displayItems
                vm.summaryCards = summaries
                vm.scanProgress = 1.0
                vm.scanTask = "Complete"
                vm.isLoading = false
            }
        }
    }

    // MARK: - Helpers

    private static func filterTag(_ ext: String, path: String, category: CategoryType) -> String {
        switch category {
        case .systemJunk:
            if path.contains("Caches") { return "Caches" }
            if path.contains("Logs") { return "Logs" }
            if path.contains(".lproj") { return "Language" }
            return "Preferences"
        case .duplicates:
            if ["jpg","jpeg","heic","png","gif"].contains(ext) { return "Photos" }
            if ["pdf","doc","docx","xls","xlsx","pptx"].contains(ext) { return "Documents" }
            if ["mp3","wav","aac","m4a","flac"].contains(ext) { return "Audio" }
            return "Downloads"
        case .largeFiles:
            if ["mov","mp4","avi","mkv","m4v"].contains(ext) { return "Video" }
            if ["mp3","wav","aac","m4a","flac"].contains(ext) { return "Audio" }
            if ["jpg","jpeg","heic","png","gif","raw","cr2","psd"].contains(ext) { return "Images" }
            if ["zip","tar","gz","dmg","pkg","rar"].contains(ext) { return "Archives" }
            return "Documents"
        case .downloads:
            if ["dmg","pkg"].contains(ext) { return "Installers (DMG/PKG)" }
            if ["jpg","jpeg","heic","png","gif","webp"].contains(ext) { return "Images" }
            return "Older than 30d"
        case .photos:
            if ext == "png" && path.lowercased().contains("screenshot") { return "Screenshots" }
            if ["raw","cr2","nef","arw","dng"].contains(ext) { return "RAW" }
            if path.contains("Live") { return "Live Photos" }
            return "Similar"
        case .developerJunk:
            if path.contains("Xcode") || path.contains("DerivedData") { return "Xcode" }
            if path.contains("Simulator") { return "Simulators" }
            if path.contains("node_modules") { return "node_modules" }
            return "Caches"
        default:
            return "All"
        }
    }

    private static func buildSummary(_ cat: CategoryType, items: [CategoryItem], totalBytes: Int64) -> [SummaryCard] {
        let count = items.count
        switch cat {
        case .systemJunk:
            let caches = items.filter { $0.filterTag == "Caches" }.reduce(0) { $0 + $1.bytes }
            let logs = items.filter { $0.filterTag == "Logs" }.reduce(0) { $0 + $1.bytes }
            let lang = items.filter { $0.filterTag == "Language" }.reduce(0) { $0 + $1.bytes }
            let prefs = items.filter { $0.filterTag == "Preferences" }.reduce(0) { $0 + $1.bytes }
            return [
                .init(id: "caches", label: "User Caches",    value: fmt(caches), isAccent: true),
                .init(id: "logs",   label: "System Logs",    value: fmt(logs),   isAccent: true),
                .init(id: "lang",   label: "Language Files",  value: fmt(lang),   isAccent: true),
                .init(id: "prefs",  label: "Broken Prefs",   value: fmt(prefs),  isAccent: true),
            ]
        case .developerJunk:
            let xcode = items.filter { $0.filterTag == "Xcode" }.reduce(0) { $0 + $1.bytes }
            let sims = items.filter { $0.filterTag == "Simulators" }.reduce(0) { $0 + $1.bytes }
            let node = items.filter { $0.filterTag == "node_modules" }.reduce(0) { $0 + $1.bytes }
            let caches = items.filter { $0.filterTag == "Caches" }.reduce(0) { $0 + $1.bytes }
            return [
                .init(id: "xcode", label: "Xcode DerivedData", value: fmt(xcode),  isAccent: true),
                .init(id: "sims",  label: "iOS Simulators",    value: fmt(sims),   isAccent: true),
                .init(id: "node",  label: "node_modules",      value: fmt(node),   isAccent: true),
                .init(id: "cache", label: "Archives / Caches", value: fmt(caches), isAccent: true),
            ]
        case .downloads:
            let old = items.filter { $0.filterTag == "Older than 30d" }.count
            let installers = items.filter { $0.filterTag == "Installers (DMG/PKG)" }.count
            return [
                .init(id: "files", label: "Total Files",      value: "\(count)",       isAccent: false),
                .init(id: "size",  label: "Total Size",       value: fmt(totalBytes),  isAccent: true),
                .init(id: "old",   label: "Older than 30d",   value: "\(old) files",   isAccent: false),
                .init(id: "inst",  label: "Installers",       value: "\(installers)",  isAccent: false),
            ]
        case .mailCleanup:
            return [
                .init(id: "acct",   label: "Accounts Scanned", value: "Local",         isAccent: false),
                .init(id: "attach", label: "Attachments",       value: "\(count)",      isAccent: false),
                .init(id: "size",   label: "Mailbox Cache",     value: fmt(totalBytes), isAccent: true),
                .init(id: "oldest", label: "Oldest",            value: items.last?.lastTouched ?? "\u{2014}", isAccent: false),
            ]
        case .largeFiles:
            let videos = items.filter { $0.filterTag == "Video" }
            let archives = items.filter { $0.filterTag == "Archives" }
            return [
                .init(id: "thresh", label: "Threshold",  value: "> 100 MB",       isAccent: false),
                .init(id: "match",  label: "Matches",    value: "\(count) files", isAccent: false),
                .init(id: "size",   label: "Total Size", value: fmt(totalBytes),  isAccent: true),
                .init(id: "largest", label: "Largest Type", value: videos.count > archives.count ? "Video \u{00B7} \(videos.count)" : "Archives \u{00B7} \(archives.count)", isAccent: false),
            ]
        case .duplicates:
            let photos = items.filter { $0.filterTag == "Photos" }
            let docs = items.filter { $0.filterTag == "Documents" }
            return [
                .init(id: "files", label: "Files Scanned",   value: "\(count)",       isAccent: false),
                .init(id: "size",  label: "Potential Dupes",  value: fmt(totalBytes),  isAccent: true),
                .init(id: "photos", label: "Photos",         value: "\(photos.count)", isAccent: false),
                .init(id: "docs",  label: "Documents",        value: "\(docs.count)",  isAccent: false),
            ]
        default:
            return [
                .init(id: "items", label: "Items Found", value: "\(count)",       isAccent: false),
                .init(id: "size",  label: "Total Size",  value: fmt(totalBytes),  isAccent: true),
            ]
        }
    }

    // MARK: - Safety Filters

    /// Paths that must never be listed or deleted
    private static func isProtectedPath(_ path: String) -> Bool {
        let protected = [
            "/System/",
            "/usr/",
            "/bin/",
            "/sbin/",
            "/private/var/",
            "/Library/Apple/",
            "/Library/SystemConfiguration/",
            "/.Spotlight-",
            "/.fseventsd",
            "/.Trashes",
            "/Volumes/",
            ".app/Contents/MacOS/",     // running executables
            ".app/Contents/Info.plist", // app metadata
            ".app/Contents/_CodeSignature/",
            "com.apple.bird/",          // iCloud daemon
            "com.apple.CloudKit/",
            "com.apple.nsurlsessiond/",
            "CloudStorage/",
            "Mobile Documents/",        // iCloud Drive
        ]
        return protected.contains { path.contains($0) }
    }

    /// Files actively in use or critical for running apps
    private static func isActivelyUsedFile(_ path: String) -> Bool {
        let skip = [
            ".DS_Store",
            ".localized",
            "Cookies.binarycookies",    // active browser cookies
            "Keychain",
            ".lock",
            ".pid",
            ".socket",
            "com.apple.LaunchServices", // app registry
            "com.apple.iconservices",   // icon cache needed by Finder
            "com.apple.dock.iconcache",
        ]
        let name = (path as NSString).lastPathComponent
        return skip.contains { name.contains($0) }
    }

    static func fmt(_ b: Int64) -> String {
        let gb = Double(b) / 1_073_741_824.0
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        let mb = Double(b) / 1_000_000.0
        if mb >= 1.0 { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(b) / 1_000.0)
    }

    private static func thumbLabel(_ ext: String) -> String {
        switch ext {
        case "pdf": return "PDF"
        case "jpg", "jpeg", "heic", "png", "gif", "webp": return "IMG"
        case "mov", "mp4", "avi", "mkv", "m4v": return "MOV"
        case "mp3", "wav", "aac", "m4a", "flac": return "AUD"
        case "zip", "tar", "gz": return "ZIP"
        case "dmg": return "DMG"
        case "pkg": return "PKG"
        case "app": return "APP"
        case "plist": return "PL"
        case "log": return "LG"
        case "swift", "py", "js", "ts", "c", "h", "m": return "</>"
        default:
            let upper = ext.prefix(3).uppercased()
            return upper.isEmpty ? "FL" : upper
        }
    }

    private static func typeLabel(_ ext: String, category: CategoryType) -> String {
        switch ext {
        case "pdf": return "Document"
        case "jpg", "jpeg", "heic", "png", "gif", "webp": return "Image"
        case "mov", "mp4", "avi", "mkv", "m4v": return "Video"
        case "mp3", "wav", "aac", "m4a", "flac": return "Audio"
        case "zip", "tar", "gz", "rar", "7z": return "Archive"
        case "dmg": return "Disk Image"
        case "pkg": return "Installer"
        case "log": return "System Log"
        case "plist": return "Preference"
        default:
            if category == .systemJunk { return "Cache" }
            if category == .mailCleanup { return "Mail Data" }
            return ext.isEmpty ? "File" : ext.uppercased()
        }
    }

    private static func relativeDate(_ date: Date?) -> String {
        guard let date = date else { return "\u{2014}" }
        let days = Int(-date.timeIntervalSinceNow / 86400)
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days) days ago" }
        if days < 30 { return "\(days / 7) wks ago" }
        if days < 365 { return "\(days / 30) mo ago" }
        return "\(days / 365) yr ago"
    }
}
