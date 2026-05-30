// App/Sources/Views/Categories/UninstallerViewModel.swift

import Foundation
import SwiftUI
import PareKit

struct AppEntry: Identifiable {
    let id: String
    let name: String
    let meta: String
    let bundleId: String
    let appBytes: Int64
    var residueBytes: Int64
    var residuePaths: [URL]   // actual paths to delete
    var isSelected: Bool
    let iconColor: Color
    let url: URL

    var appSizeLabel: String { Self.fmt(appBytes) }
    var residueLabel: String { Self.fmt(residueBytes) }
    var totalBytes: Int64 { appBytes + residueBytes }
    var totalLabel: String { Self.fmt(totalBytes) }

    static func fmt(_ b: Int64) -> String {
        let gb = Double(b) / 1_073_741_824.0
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        let mb = Double(b) / 1_000_000.0
        if mb >= 1.0 { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(b) / 1_000.0)
    }
}

final class UninstallerViewModel: ObservableObject {
    @Published var installedApps: [AppEntry] = []
    @Published var leftovers: [AppEntry] = []
    @Published var displayedApps: [AppEntry] = []
    @Published var isLoading = true
    @Published var scanProgress: Double = 0
    @Published var scanTask: String = "Scanning applications..."
    @Published var activeFilter: String = "Installed apps" {
        didSet { applyFilter() }
    }
    @Published var showConfirm = false
    @Published var showPaywall = false
    @Published var showSuccess = false
    @Published var cleanedCount = 0
    @Published var cleanedSize: Int64 = 0

    /// True when the App is walking the filesystem directly. Banner shown.
    @Published var isLimitedMode: Bool = false

    var selectedCount: Int {
        displayedApps.filter(\.isSelected).count + leftovers.filter(\.isSelected).count
    }
    var selectedBytes: Int64 {
        displayedApps.filter(\.isSelected).reduce(0) { $0 + $1.totalBytes } +
        leftovers.filter(\.isSelected).reduce(0) { $0 + $1.totalBytes }
    }
    var selectedSizeLabel: String { AppEntry.fmt(selectedBytes) }

    private static let iconColors: [Color] = [
        Color(red: 0.106, green: 0.369, blue: 0.247),
        Color(red: 0.494, green: 0.227, blue: 0.278),
        Color(red: 0.231, green: 0.353, blue: 0.549),
        Color(red: 0.722, green: 0.455, blue: 0.173),
        Color(red: 0.345, green: 0.447, blue: 0.267),
        Color(red: 0.420, green: 0.173, blue: 0.522),
        Color(red: 0.082, green: 0.078, blue: 0.059),
        Color(red: 0.592, green: 0.580, blue: 0.549),
    ]

    init() {
        Task { @MainActor in
            let handled = await self.loadViaHelper()
            if !handled {
                self.isLimitedMode = true
                self.loadAppsLocally()
            }
        }
    }

    /// Attempt to load apps + residue + leftovers via the privileged helper.
    /// Returns false when the helper isn't enabled or errored.
    @MainActor
    private func loadViaHelper() async -> Bool {
        let vm = self
        let scanItems = await HelperScanRoute.fetch(categories: [.uninstaller]) { progress in
            Task { @MainActor in
                vm.scanTask = progress.currentTask
                vm.scanProgress = progress.percent
            }
        }
        guard let scanItems = scanItems else { return false }

        let entries = Self.assembleEntries(from: scanItems)
        installedApps = entries.installed
        leftovers = entries.leftovers
        applyFilter()
        scanProgress = 1.0
        scanTask = "Complete (via helper)"
        isLoading = false
        isLimitedMode = false
        return true
    }

    /// Translates the helper's flat `[ScanItem]` into the App's
    /// `installedApps + leftovers` shape, grouping by `groupID`.
    /// - Item with `subcategory == "app"` becomes the head of an installed entry.
    /// - Items with `subcategory == "leftover"` group into a leftover entry,
    ///   keyed by `groupID` (the scanner shares one per inferred bundle id).
    /// - `subcategory == "residue"` items attach to the matching app via groupID.
    private static func assembleEntries(
        from items: [ScanItem]
    ) -> (installed: [AppEntry], leftovers: [AppEntry]) {
        let grouped = Dictionary(grouping: items) { $0.groupID ?? UUID() }
        var installed: [AppEntry] = []
        var leftovers: [AppEntry] = []
        var iconIndex = 0

        for (_, group) in grouped {
            let head = group.first { $0.metadata["subcategory"] == "app" }
                ?? group.first { $0.metadata["subcategory"] == "leftover" }
            guard let head = head else { continue }

            let isLeftover = head.metadata["subcategory"] == "leftover"
            let nonHead = group.filter { $0.id != head.id }
            let residueBytes = nonHead.reduce(Int64(0)) { $0 + $1.bytes }
            let residuePaths = nonHead.map(\.path)
            let bundleID = head.metadata["bundle_id"] ?? ""
            let displayName = head.metadata["display_name"]
                ?? bundleID.split(separator: ".").last.map(String.init)?.capitalized
                ?? head.path.deletingPathExtension().lastPathComponent

            let color = iconColors[iconIndex % iconColors.count]
            iconIndex += 1

            let meta: String
            if isLeftover {
                meta = "Caches, prefs, app support left over \u{00B7} \(group.count) paths"
            } else {
                let lastUsed = relativeDate(head.lastAccessed)
                meta = "last used \(lastUsed)"
            }

            let entry = AppEntry(
                id: head.path.path,
                name: displayName,
                meta: meta,
                bundleId: bundleID,
                appBytes: isLeftover ? 0 : head.bytes,
                residueBytes: residueBytes,
                residuePaths: residuePaths + (isLeftover ? [head.path] : []),
                isSelected: isLeftover,
                iconColor: color,
                url: head.path
            )
            if isLeftover {
                leftovers.append(entry)
            } else {
                installed.append(entry)
            }
        }

        installed.sort { $0.totalBytes > $1.totalBytes }
        leftovers.sort { $0.totalBytes > $1.totalBytes }
        return (installed, leftovers)
    }

    func toggleApp(_ id: String) {
        if let i = displayedApps.firstIndex(where: { $0.id == id }) {
            displayedApps[i].isSelected.toggle()
        }
        if let i = installedApps.firstIndex(where: { $0.id == id }) {
            installedApps[i].isSelected.toggle()
        }
    }

    func toggleLeftover(_ id: String) {
        if let i = leftovers.firstIndex(where: { $0.id == id }) {
            leftovers[i].isSelected.toggle()
        }
    }

    func selectAll() {
        for i in displayedApps.indices { displayedApps[i].isSelected = true }
        for i in installedApps.indices { installedApps[i].isSelected = true }
        for i in leftovers.indices { leftovers[i].isSelected = true }
    }

    func deselectAll() {
        for i in displayedApps.indices { displayedApps[i].isSelected = false }
        for i in installedApps.indices { installedApps[i].isSelected = false }
        for i in leftovers.indices { leftovers[i].isSelected = false }
    }

    func reviewAndClean() {
        guard selectedCount > 0 else { return }
        let licence = LicenceManager.shared
        if licence.wouldExceedLimit(bytes: selectedBytes) {
            showPaywall = true
            return
        }
        showConfirm = true
    }

    func confirmClean() {
        showConfirm = false
        let toClean = displayedApps.filter(\.isSelected) + leftovers.filter(\.isSelected)
        let store = CleanedItemStore.shared
        var cleanedIds: Set<String> = []
        cleanedCount = 0
        cleanedSize = 0

        for app in toClean {
            var success = false

            // 1. Move the .app bundle to recovery bin
            if app.appBytes > 0 && FileManager.default.fileExists(atPath: app.url.path) {
                let moved = store.moveToRecoveryBin(
                    url: app.url, fileName: "\(app.name).app",
                    originalPath: app.url.path, category: "Uninstaller",
                    bytes: app.appBytes
                )
                if moved { success = true }
            }

            // 2. Delete all residue paths
            for residuePath in app.residuePaths {
                if FileManager.default.fileExists(atPath: residuePath.path) &&
                   FileManager.default.isDeletableFile(atPath: residuePath.path) {
                    do {
                        try FileManager.default.removeItem(at: residuePath)
                        success = true
                    } catch {
                        // try trash as fallback
                        let _ = try? FileManager.default.trashItem(at: residuePath, resultingItemURL: nil)
                    }
                }
            }

            // Record residue removal in store
            if app.residueBytes > 0 && success {
                store.addBatch([(fileName: "\(app.name) residue", path: "~/Library/...", category: "Uninstaller", bytes: app.residueBytes)])
            }

            if success {
                cleanedIds.insert(app.id)
                cleanedCount += 1
                cleanedSize += app.totalBytes
            }
        }

        // Record usage
        LicenceManager.shared.recordCleanup(bytes: cleanedSize)

        installedApps.removeAll { cleanedIds.contains($0.id) }
        leftovers.removeAll { cleanedIds.contains($0.id) }
        applyFilter()
        showSuccess = cleanedCount > 0
    }

    func cancelClean() {
        showConfirm = false
    }

    private func applyFilter() {
        if activeFilter.hasPrefix("Leftover") {
            displayedApps = []
        } else if activeFilter == "Large apps" {
            displayedApps = installedApps.filter { $0.totalBytes > 500_000_000 }
        } else {
            displayedApps = installedApps
        }
    }

    // MARK: - Scan (local fallback)

    private func loadAppsLocally() {
        let vm = self
        let home = FileManager.default.homeDirectoryForCurrentUser

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default

            DispatchQueue.main.async { vm.scanTask = "Scanning /Applications..."; vm.scanProgress = 0.1 }

            let appsURL = URL(fileURLWithPath: "/Applications")
            var apps: [AppEntry] = []
            var bundleIds: Set<String> = []

            if let contents = try? fm.contentsOfDirectory(at: appsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                let appBundles = contents.filter { $0.pathExtension == "app" }

                for (idx, appURL) in appBundles.enumerated() {
                    let name = appURL.deletingPathExtension().lastPathComponent
                    let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
                    var bundleId = ""
                    var version = ""

                    if let data = try? Data(contentsOf: plistURL),
                       let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                        bundleId = (plist["CFBundleIdentifier"] as? String) ?? ""
                        version = (plist["CFBundleShortVersionString"] as? String) ?? ""
                    }

                    if !bundleId.isEmpty { bundleIds.insert(bundleId) }

                    // Fast app size using allocatedSize resource key
                    let appSize = Self.fastDirectorySize(appURL)

                    // Find all residue paths
                    let (residueSize, residuePaths) = Self.findAllResidue(bundleId: bundleId, appName: name, home: home)

                    let accessDate = (try? appURL.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate
                    let lastUsed = Self.relativeDate(accessDate)
                    let meta = version.isEmpty ? "last used \(lastUsed)" : "Version \(version) \u{00B7} last used \(lastUsed)"
                    let color = Self.iconColors[idx % Self.iconColors.count]

                    apps.append(AppEntry(
                        id: appURL.path, name: name, meta: meta, bundleId: bundleId,
                        appBytes: appSize, residueBytes: residueSize, residuePaths: residuePaths,
                        isSelected: false, iconColor: color, url: appURL
                    ))

                    if idx % 5 == 0 {
                        let p = 0.1 + 0.6 * Double(idx) / Double(appBundles.count)
                        DispatchQueue.main.async { vm.scanProgress = p; vm.scanTask = "Scanning \(name)..." }
                    }
                }
            }

            apps.sort { $0.totalBytes > $1.totalBytes }

            // Step 2: Find leftover data
            DispatchQueue.main.async { vm.scanTask = "Finding leftover data..."; vm.scanProgress = 0.8 }

            var foundLeftovers: [AppEntry] = []
            let libraryDirs = ["Application Support", "Caches", "Preferences",
                               "Containers", "Group Containers",
                               "Saved Application State", "HTTPStorages", "WebKit"]
            var leftoverMap: [String: (bytes: Int64, paths: [URL])] = [:]

            for dir in libraryDirs {
                let libDir = home.appendingPathComponent("Library/\(dir)")
                guard let contents = try? fm.contentsOfDirectory(at: libDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                for item in contents {
                    let itemName = item.lastPathComponent
                    let looksLikeBundleId = itemName.contains(".") && itemName.split(separator: ".").count >= 3
                    let matchesInstalled = bundleIds.contains(itemName) ||
                        apps.contains(where: { itemName.localizedCaseInsensitiveContains($0.name) || itemName == $0.bundleId })

                    if looksLikeBundleId && !matchesInstalled {
                        let size = Self.fastDirectorySize(item)
                        if size > 500_000 {
                            var entry = leftoverMap[itemName] ?? (bytes: 0, paths: [])
                            entry.bytes += size
                            entry.paths.append(item)
                            leftoverMap[itemName] = entry
                        }
                    }
                }
            }

            // Also check LaunchAgents for leftover plists
            let agentDir = home.appendingPathComponent("Library/LaunchAgents")
            if let agents = try? fm.contentsOfDirectory(at: agentDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for agent in agents where agent.pathExtension == "plist" {
                    let agentName = agent.deletingPathExtension().lastPathComponent
                    if !bundleIds.contains(where: { agentName.contains($0) }) {
                        let size = (try? fm.attributesOfItem(atPath: agent.path)[.size] as? Int64) ?? 0
                        var entry = leftoverMap[agentName] ?? (bytes: 0, paths: [])
                        entry.bytes += size
                        entry.paths.append(agent)
                        leftoverMap[agentName] = entry
                    }
                }
            }

            for (name, info) in leftoverMap.sorted(by: { $0.value.bytes > $1.value.bytes }).prefix(20) {
                let displayName = name.split(separator: ".").last.map(String.init) ?? name
                foundLeftovers.append(AppEntry(
                    id: "leftover-\(name)", name: displayName.capitalized,
                    meta: "Caches, prefs, app support left over \u{00B7} \(info.paths.count) paths",
                    bundleId: name, appBytes: 0, residueBytes: info.bytes, residuePaths: info.paths,
                    isSelected: true, iconColor: Color(red: 0.592, green: 0.580, blue: 0.549),
                    url: info.paths.first ?? home
                ))
            }

            DispatchQueue.main.async {
                vm.installedApps = apps
                vm.displayedApps = apps
                vm.leftovers = foundLeftovers
                vm.scanProgress = 1.0
                vm.scanTask = "Complete"
                vm.isLoading = false
            }
        }
    }

    // MARK: - Fast Directory Size (uses allocatedSize, much faster than enumerating)

    private static func fastDirectorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: - Find ALL Residue (comprehensive search)

    private static func findAllResidue(bundleId: String, appName: String, home: URL) -> (Int64, [URL]) {
        guard !bundleId.isEmpty else { return (0, []) }
        let fm = FileManager.default
        var total: Int64 = 0
        var paths: [URL] = []

        // All known residue locations
        let candidates = [
            home.appendingPathComponent("Library/Caches/\(bundleId)"),
            home.appendingPathComponent("Library/Application Support/\(bundleId)"),
            home.appendingPathComponent("Library/Application Support/\(appName)"),
            home.appendingPathComponent("Library/Preferences/\(bundleId).plist"),
            home.appendingPathComponent("Library/Saved Application State/\(bundleId).savedState"),
            home.appendingPathComponent("Library/Containers/\(bundleId)"),
            home.appendingPathComponent("Library/Group Containers/\(bundleId)"),
            home.appendingPathComponent("Library/HTTPStorages/\(bundleId)"),
            home.appendingPathComponent("Library/WebKit/\(bundleId)"),
            home.appendingPathComponent("Library/Logs/\(bundleId)"),
            home.appendingPathComponent("Library/Cookies/\(bundleId).binarycookies"),
        ]

        for path in candidates {
            guard fm.fileExists(atPath: path.path) else { continue }
            var isDir: ObjCBool = false
            fm.fileExists(atPath: path.path, isDirectory: &isDir)
            let size: Int64
            if isDir.boolValue {
                size = fastDirectorySize(path)
            } else {
                size = (try? fm.attributesOfItem(atPath: path.path)[.size] as? Int64) ?? 0
            }
            if size > 0 {
                total += size
                paths.append(path)
            }
        }

        // Also search LaunchAgents for matching plists
        let agentDir = home.appendingPathComponent("Library/LaunchAgents")
        if let agents = try? fm.contentsOfDirectory(at: agentDir, includingPropertiesForKeys: nil, options: []) {
            for agent in agents where agent.lastPathComponent.contains(bundleId) {
                let size = (try? fm.attributesOfItem(atPath: agent.path)[.size] as? Int64) ?? 0
                total += size
                paths.append(agent)
            }
        }

        return (total, paths)
    }

    private static func relativeDate(_ date: Date?) -> String {
        guard let date = date else { return "unknown" }
        let days = Int(-date.timeIntervalSinceNow / 86400)
        if days == 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 30 { return "\(days) days ago" }
        if days < 365 { return "\(days / 30) months ago" }
        return "\(days / 365) years ago"
    }
}
