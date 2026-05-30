// Helper/Sources/Scanners/UninstallerScanner.swift
//
// FR-07 — enumerates installed apps and the residue keyed by their bundle
// IDs. Two passes:
//
//   1. Walk `/Applications` + `~/Applications`. For each `.app` bundle,
//      emit one `ScanItem` with `subcategory = "app"` plus zero or more
//      `subcategory = "residue"` items keyed by `groupID` for the
//      bundle-keyed residue (Caches, Preferences, Containers, etc.).
//   2. Scan the same Library subdirectories for directories/plists whose
//      names look like reverse-DNS bundle identifiers but don't match any
//      installed app. Emit those as `subcategory = "leftover"` items,
//      grouped by inferred bundle id.
//
// `detectResidue` defaults to `true` for production callers; HelperTests
// can pass `false` to test the cheap "apps only" path in isolation.

import Foundation
import PareKit

public struct UninstallerScanner: Scanner {
    public let category: PareKit.Category = .uninstaller

    public let roots: [URL]
    public let userHome: URL
    public let detectResidue: Bool
    public let leftoverMinBytes: Int64
    public let progressEveryNApps: Int

    public init(
        roots: [URL]? = nil,
        userHome: URL? = nil,
        detectResidue: Bool = true,
        leftoverMinBytes: Int64 = 500_000,
        progressEveryNApps: Int = 5
    ) {
        self.roots = roots ?? Self.defaultRoots()
        self.userHome = userHome ?? URL(fileURLWithPath: ProtectedPaths.currentUserHome())
        self.detectResidue = detectResidue
        self.leftoverMinBytes = max(0, leftoverMinBytes)
        self.progressEveryNApps = max(1, progressEveryNApps)
    }

    private static func defaultRoots() -> [URL] {
        let home = URL(fileURLWithPath: ProtectedPaths.currentUserHome())
        return [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications"),
        ]
    }

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        var results: [ScanItem] = []
        var bundleIDs: Set<String> = []
        var appsScanned = 0
        var bytesFound: Int64 = 0
        let totalRoots = max(1, roots.count)

        // ── Pass 1: apps + their residue ────────────────────────────────
        for (rootIdx, root) in roots.enumerated() {
            try Task.checkCancellation()
            let apps = enumerateApps(under: root)

            for app in apps {
                try Task.checkCancellation()
                let groupID = UUID()
                let bundleID = app.bundleID
                if !bundleID.isEmpty { bundleIDs.insert(bundleID) }

                results.append(
                    ScanItem(
                        path: app.url,
                        category: .uninstaller,
                        bytes: app.bytes,
                        lastModified: app.modified,
                        lastAccessed: app.accessed,
                        riskLevel: .caution,
                        groupID: groupID,
                        metadata: [
                            "subcategory": "app",
                            "bundle_id": bundleID,
                            "display_name": app.displayName,
                        ]
                    )
                )
                bytesFound += app.bytes

                if detectResidue && !bundleID.isEmpty {
                    let residue = findResidue(
                        bundleID: bundleID,
                        displayName: app.displayName,
                        groupID: groupID
                    )
                    results.append(contentsOf: residue)
                    bytesFound += residue.reduce(0) { $0 + $1.bytes }
                }

                appsScanned += 1
                if appsScanned % progressEveryNApps == 0 {
                    progress(
                        ScanProgress(
                            percent: Double(rootIdx) / Double(totalRoots),
                            currentTask: "Scanning installed apps",
                            currentPath: app.url.path,
                            filesScanned: appsScanned,
                            bytesFoundSoFar: bytesFound,
                            estimatedSecondsLeft: nil
                        )
                    )
                }
            }
        }

        // ── Pass 2: leftover residue from already-uninstalled apps ─────
        if detectResidue {
            progress(
                ScanProgress(
                    percent: 0.9,
                    currentTask: "Finding leftover residue",
                    currentPath: "",
                    filesScanned: appsScanned,
                    bytesFoundSoFar: bytesFound,
                    estimatedSecondsLeft: nil
                )
            )
            let leftovers = findLeftovers(installedBundleIDs: bundleIDs)
            results.append(contentsOf: leftovers)
            bytesFound += leftovers.reduce(0) { $0 + $1.bytes }
        }

        progress(
            ScanProgress(
                percent: 1.0,
                currentTask: "Uninstaller scan complete",
                currentPath: "",
                filesScanned: appsScanned,
                bytesFoundSoFar: bytesFound,
                estimatedSecondsLeft: 0
            )
        )
        return results
    }

    // MARK: - Pass 1 helpers

    private struct AppRecord {
        let url: URL
        let bundleID: String
        let displayName: String
        let bytes: Int64
        let modified: Date
        let accessed: Date
    }

    private func enumerateApps(under root: URL) -> [AppRecord] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { return [] }
        guard
            let children = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [
                    .contentModificationDateKey, .contentAccessDateKey,
                ],
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        var apps: [AppRecord] = []
        for appURL in children {
            guard appURL.pathExtension == "app" else { continue }
            if ProtectedPaths.isProtected(appURL) { continue }

            let bundleID = Self.bundleIdentifier(of: appURL) ?? ""
            let displayName = appURL.deletingPathExtension().lastPathComponent
            let values = try? appURL.resourceValues(forKeys: [
                .contentModificationDateKey, .contentAccessDateKey,
            ])
            apps.append(
                AppRecord(
                    url: appURL,
                    bundleID: bundleID,
                    displayName: displayName,
                    bytes: Self.bundleSize(of: appURL),
                    modified: values?.contentModificationDate ?? Date.distantPast,
                    accessed: values?.contentAccessDate ?? Date.distantPast
                )
            )
        }
        return apps
    }

    private func findResidue(bundleID: String, displayName: String, groupID: UUID) -> [ScanItem] {
        let candidates: [(URL, String)] = [
            (userHome.appendingPathComponent("Library/Caches/\(bundleID)"), "cache"),
            (userHome.appendingPathComponent("Library/Application Support/\(bundleID)"), "app-support"),
            (userHome.appendingPathComponent("Library/Application Support/\(displayName)"), "app-support"),
            (userHome.appendingPathComponent("Library/Preferences/\(bundleID).plist"), "preferences"),
            (userHome.appendingPathComponent("Library/Saved Application State/\(bundleID).savedState"), "saved-state"),
            (userHome.appendingPathComponent("Library/Containers/\(bundleID)"), "container"),
            (userHome.appendingPathComponent("Library/Group Containers/\(bundleID)"), "group-container"),
            (userHome.appendingPathComponent("Library/HTTPStorages/\(bundleID)"), "http-storage"),
            (userHome.appendingPathComponent("Library/WebKit/\(bundleID)"), "webkit"),
            (userHome.appendingPathComponent("Library/Logs/\(bundleID)"), "logs"),
            (userHome.appendingPathComponent("Library/Cookies/\(bundleID).binarycookies"), "cookies"),
        ]

        let fm = FileManager.default
        var items: [ScanItem] = []
        for (url, kind) in candidates {
            guard fm.fileExists(atPath: url.path) else { continue }
            if ProtectedPaths.isProtected(url) { continue }

            let size = Self.itemSize(url)
            guard size > 0 else { continue }

            items.append(
                ScanItem(
                    path: url,
                    category: .uninstaller,
                    bytes: size,
                    lastModified: Self.modificationDate(url),
                    lastAccessed: Self.accessDate(url),
                    riskLevel: .caution,
                    groupID: groupID,
                    metadata: [
                        "subcategory": "residue",
                        "residue_kind": kind,
                        "bundle_id": bundleID,
                    ]
                )
            )
        }
        return items
    }

    // MARK: - Pass 2: leftovers

    private static let leftoverLibraryDirs = [
        "Library/Application Support",
        "Library/Caches",
        "Library/Containers",
        "Library/Group Containers",
        "Library/Saved Application State",
        "Library/HTTPStorages",
        "Library/WebKit",
        "Library/Logs",
        "Library/Preferences",
    ]

    private func findLeftovers(installedBundleIDs: Set<String>) -> [ScanItem] {
        let fm = FileManager.default
        // bundle id → (groupID, items)
        var byBundle: [String: (groupID: UUID, items: [ScanItem])] = [:]

        for dir in Self.leftoverLibraryDirs {
            let parent = userHome.appendingPathComponent(dir)
            guard
                let children = try? fm.contentsOfDirectory(
                    at: parent,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else { continue }

            for item in children {
                let bundleID = Self.inferredBundleID(from: item.lastPathComponent)
                guard Self.looksLikeBundleID(bundleID) else { continue }
                if installedBundleIDs.contains(bundleID) { continue }
                if ProtectedPaths.isProtected(item) { continue }

                let size = Self.itemSize(item)
                guard size >= leftoverMinBytes else { continue }

                let entryGroupID = byBundle[bundleID]?.groupID ?? UUID()
                let leftover = ScanItem(
                    path: item,
                    category: .uninstaller,
                    bytes: size,
                    lastModified: Self.modificationDate(item),
                    lastAccessed: Self.accessDate(item),
                    riskLevel: .caution,
                    groupID: entryGroupID,
                    metadata: [
                        "subcategory": "leftover",
                        "bundle_id": bundleID,
                    ]
                )
                var entry = byBundle[bundleID] ?? (groupID: entryGroupID, items: [])
                entry.items.append(leftover)
                byBundle[bundleID] = entry
            }
        }

        return byBundle.values.flatMap { $0.items }
    }

    /// Strip well-known suffixes so `com.foo.bar.plist`, `com.foo.bar.savedState`,
    /// and `com.foo.bar.binarycookies` all reduce to `com.foo.bar`.
    private static func inferredBundleID(from name: String) -> String {
        let suffixes = [".plist", ".savedState", ".binarycookies"]
        for suffix in suffixes where name.hasSuffix(suffix) {
            return String(name.dropLast(suffix.count))
        }
        return name
    }

    /// Reverse-DNS heuristic: at least two dots (e.g. `com.foo.bar`).
    private static func looksLikeBundleID(_ s: String) -> Bool {
        s.contains(".") && s.split(separator: ".").count >= 3
    }

    // MARK: - Shared file helpers

    private static func itemSize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: url.path) {
            let type = attrs[.type] as? FileAttributeType
            if type == .typeRegular {
                return (attrs[.size] as? Int64) ?? 0
            }
        }
        return bundleSize(of: url)
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            ?? Date.distantPast
    }

    private static func accessDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate
            ?? Date.distantPast
    }

    /// Recursive size of a bundle on disk. Errors during enumeration are
    /// swallowed — partial sizes are better than failing the whole scan.
    private static func bundleSize(of url: URL) -> Int64 {
        let fm = FileManager.default
        guard
            let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [],
                errorHandler: { _, _ in true }
            )
        else { return 0 }
        var total: Int64 = 0
        while let next = enumerator.nextObject() {
            guard
                let fileURL = next as? URL,
                let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                values.isRegularFile == true,
                let size = values.fileSize
            else { continue }
            total += Int64(size)
        }
        return total
    }

    /// Reads `CFBundleIdentifier` from `<app>/Contents/Info.plist`.
    private static func bundleIdentifier(of url: URL) -> String? {
        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        guard
            let data = try? Data(contentsOf: infoPlist),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleIdentifier"] as? String
    }
}
