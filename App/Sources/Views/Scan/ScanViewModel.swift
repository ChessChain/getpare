// App/Sources/Views/Scan/ScanViewModel.swift

import Foundation
import Combine
import PareKit

public final class ScanViewModel: ObservableObject {
    enum ScanMode { case standard, deep }

    @Published public var percent: Double = 0
    @Published public var currentTask: String = "Ready to scan"
    @Published public var currentPath: String = ""
    @Published public var filesScanned: Int = 0
    @Published public var bytesFoundSoFar: Int64 = 0
    @Published public var estimatedTimeLeft: String = "\u{2014}"
    @Published public var isScanning: Bool = false
    @Published public var scanComplete: Bool = false
    @Published var scanMode: ScanMode = .standard

    private var cancelled = false

    public var foundSoFarFormatted: String {
        ByteCountFormatter.string(fromByteCount: bytesFoundSoFar, countStyle: .file)
    }

    public init() {}

    /// Runs a real filesystem scan across key directories.
    public func startRealScan() {
        guard !isScanning else { return }
        isScanning = true
        scanComplete = false
        cancelled = false
        percent = 0
        filesScanned = 0
        bytesFoundSoFar = 0
        currentTask = "Preparing scan..."
        currentPath = ""
        estimatedTimeLeft = "calculating..."

        let home = FileManager.default.homeDirectoryForCurrentUser

        // Directories to scan
        var scanTargets: [(task: String, url: URL)] = [
            ("Scanning system caches",       home.appendingPathComponent("Library/Caches")),
            ("Scanning system logs",         home.appendingPathComponent("Library/Logs")),
            ("Scanning downloads",           home.appendingPathComponent("Downloads")),
            ("Scanning mail attachments",    home.appendingPathComponent("Library/Mail")),
            ("Scanning documents",           home.appendingPathComponent("Documents")),
            ("Scanning photos & media",      home.appendingPathComponent("Pictures")),
            ("Scanning movies",              home.appendingPathComponent("Movies")),
            ("Scanning music",               home.appendingPathComponent("Music")),
            ("Scanning developer tools",     home.appendingPathComponent("Library/Developer")),
            ("Scanning applications",        URL(fileURLWithPath: "/Applications")),
        ]

        // Deep scan: add entire ~/Library, Desktop, and system paths
        if scanMode == .deep {
            scanTargets += [
                ("Deep: scanning app support",       home.appendingPathComponent("Library/Application Support")),
                ("Deep: scanning preferences",       home.appendingPathComponent("Library/Preferences")),
                ("Deep: scanning containers",        home.appendingPathComponent("Library/Containers")),
                ("Deep: scanning saved state",       home.appendingPathComponent("Library/Saved Application State")),
                ("Deep: scanning desktop",           home.appendingPathComponent("Desktop")),
                ("Deep: scanning group containers",  home.appendingPathComponent("Library/Group Containers")),
                ("Deep: scanning WebKit data",       home.appendingPathComponent("Library/WebKit")),
                ("Deep: hashing large files",        home.appendingPathComponent("Downloads")),
            ]
        }

        let totalTargets = scanTargets.count
        let vm = self
        let startTime = Date()

        DispatchQueue.global(qos: .userInitiated).async {
            var totalFiles = 0
            var totalBytes: Int64 = 0

            for (index, target) in scanTargets.enumerated() {
                if vm.cancelled { break }

                let taskName = target.task
                let url = target.url

                DispatchQueue.main.async {
                    vm.currentTask = taskName
                    vm.currentPath = url.path.replacingOccurrences(of: home.path, with: "~")
                    vm.percent = Double(index) / Double(totalTargets)
                }

                // Enumerate files in this directory
                guard let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                    options: [.skipsPackageDescendants],
                    errorHandler: { _, _ in true }
                ) else { continue }

                var dirFiles = 0
                var dirBytes: Int64 = 0

                for case let fileURL as URL in enumerator {
                    if vm.cancelled { break }

                    guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                          values.isRegularFile == true else { continue }

                    let size = Int64(values.fileSize ?? 0)
                    dirFiles += 1
                    totalFiles += 1

                    // Only count reclaimable bytes — skip essential/protected files
                    let path = fileURL.path
                    if Self.isReclaimable(path: path, size: size) {
                        dirBytes += size
                        totalBytes += size
                    }

                    // Update UI every 500 files to avoid main thread spam
                    if dirFiles % 500 == 0 {
                        let f = totalFiles
                        let b = totalBytes
                        let p = fileURL.lastPathComponent
                        let elapsed = Date().timeIntervalSince(startTime)
                        let progressFraction = (Double(index) + Double(dirFiles) / max(1, Double(dirFiles + 1000))) / Double(totalTargets)

                        DispatchQueue.main.async {
                            vm.filesScanned = f
                            vm.bytesFoundSoFar = b
                            vm.currentPath = p
                            vm.percent = min(0.95, progressFraction)

                            // Estimate time remaining
                            if elapsed > 1 && progressFraction > 0.05 {
                                let totalEstimated = elapsed / progressFraction
                                let remaining = max(0, totalEstimated - elapsed)
                                vm.estimatedTimeLeft = remaining < 2 ? "< 2s" : "~\(Int(remaining))s"
                            }
                        }
                    }
                }

                // Final update for this directory
                let f = totalFiles
                let b = totalBytes
                DispatchQueue.main.async {
                    vm.filesScanned = f
                    vm.bytesFoundSoFar = b
                }
            }

            // Done
            DispatchQueue.main.async {
                vm.percent = 1.0
                vm.filesScanned = totalFiles
                vm.bytesFoundSoFar = totalBytes
                vm.currentTask = "Scan complete"
                vm.currentPath = "\(totalFiles.formatted()) files analysed \u{00B7} \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)) reclaimable"
                vm.estimatedTimeLeft = "done"
                vm.isScanning = false
                vm.scanComplete = true
            }
        }
    }

    /// Only count files that are actually reclaimable — caches, logs, old downloads, dev junk, etc.
    private static func isReclaimable(path: String, size: Int64) -> Bool {
        let p = path.lowercased()

        // Always reclaimable: caches, logs, temp files
        if p.contains("/caches/") || p.contains("/cache/") { return true }
        if p.contains("/logs/") || p.contains("/log/") { return true }
        if p.contains("/tmp/") || p.contains("/temp/") { return true }
        if p.contains("deriveddata") { return true }
        if p.contains("node_modules") { return true }
        if p.contains(".trash") { return true }

        // Downloads — old installers, archives
        if p.contains("/downloads/") {
            let ext = (path as NSString).pathExtension.lowercased()
            if ["dmg", "pkg", "zip", "tar", "gz", "rar", "7z"].contains(ext) { return true }
            return true // all downloads are candidates
        }

        // Mail attachments
        if p.contains("/library/mail/") { return true }

        // Saved state, containers residue
        if p.contains("saved application state") { return true }
        if p.contains("/webkit/") { return true }

        // Large files (>100MB) in user directories
        if size > 100_000_000 {
            if p.contains("/documents/") || p.contains("/movies/") || p.contains("/music/") || p.contains("/pictures/") {
                return true
            }
        }

        // Xcode/developer
        if p.contains("/developer/") { return true }

        // App support — only count large ones
        if p.contains("/application support/") && size > 10_000_000 { return true }

        // Preferences — small, skip
        if p.contains("/preferences/") { return false }

        // Group containers — count caches inside
        if p.contains("/group containers/") && (p.contains("cache") || size > 50_000_000) { return true }

        return false
    }

    public func cancelScan() {
        cancelled = true
        isScanning = false
        currentTask = "Scan cancelled"
        estimatedTimeLeft = "\u{2014}"
    }
}
