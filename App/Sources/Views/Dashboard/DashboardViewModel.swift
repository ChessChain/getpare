// App/Sources/Views/Dashboard/DashboardViewModel.swift

import Foundation
import SwiftUI
import Combine
import PareKit

public final class DashboardViewModel: ObservableObject {

    // MARK: - Storage Totals

    @Published public var capacityBytes: Int64 = 0
    @Published public var usedBytes: Int64 = 0
    @Published public var reclaimableBytes: Int64 = 0
    @Published public var reclaimableCategoryCount: Int = 0
    @Published public var userName: String = "there"
    @Published public var lastScanLabel: String = "Last scan: never"
    @Published public var isLoading: Bool = true

    public var capacityGB: Int { Int(capacityBytes / 1_073_741_824) }
    public var usedGB: Int { Int(usedBytes / 1_073_741_824) }
    public var freeBytes: Int64 { max(0, capacityBytes - usedBytes) }

    public var reclaimableSummary: String {
        ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)
    }

    // MARK: - Categories

    struct CategoryBreakdown: Identifiable {
        let id: String
        let name: String
        var bytes: Int64
        let color: Color
    }

    @Published var categories: [CategoryBreakdown] = []

    var barSegments: [StorageBarSegment] {
        categories.map { .init(label: $0.name, bytes: $0.bytes, color: $0.color) }
    }

    struct LegendItem: Identifiable {
        let id: String
        let label: String
        let sizeLabel: String
        let color: Color
    }

    var legendItems: [LegendItem] {
        var items = categories.map {
            LegendItem(id: $0.id, label: $0.name,
                       sizeLabel: ByteCountFormatter.string(fromByteCount: $0.bytes, countStyle: .file),
                       color: $0.color)
        }
        items.append(LegendItem(id: "free", label: "Free",
                                sizeLabel: ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file),
                                color: PareColor.line))
        return items
    }

    // MARK: - Trend

    enum TrendRange: CaseIterable {
        case thirty, ninety, year
        var shortLabel: String {
            switch self { case .thirty: return "30d"; case .ninety: return "90d"; case .year: return "1yr" }
        }
        var label: String {
            switch self { case .thirty: return "30-DAY"; case .ninety: return "90-DAY"; case .year: return "1-YEAR" }
        }
        var days: Int {
            switch self { case .thirty: return 30; case .ninety: return 90; case .year: return 365 }
        }
        var axisStart: String {
            switch self { case .thirty: return "30D AGO"; case .ninety: return "90D AGO"; case .year: return "1YR AGO" }
        }
        var axisMid: String {
            switch self { case .thirty: return "15D"; case .ninety: return "45D"; case .year: return "6MO" }
        }
    }

    struct TrendPoint: Identifiable { let id: Int; let date: Date; let gb: Double }
    struct CleanupMarker: Identifiable { let id: Int; let date: Date; let gb: Double }

    @Published var selectedRange: TrendRange = .ninety { didSet { rebuildTrendData() } }
    @Published var trendData: [TrendPoint] = []
    @Published var cleanupMarkers: [CleanupMarker] = []
    @Published var trendDelta: String = ""

    private func rebuildTrendData() {
        let currentGB = Double(usedBytes) / 1_073_741_824.0
        guard currentGB > 0 else { return }
        let days = selectedRange.days
        let now = Date()
        let store = CleanedItemStore.shared

        // Build real cleanup events from store history
        let cleanups = store.items.map { item -> (date: Date, gb: Double) in
            (item.cleanedDate, Double(item.bytes) / 1_073_741_824.0)
        }

        // Total cleaned in the selected period
        let periodStart = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        let periodCleanups = cleanups.filter { $0.date >= periodStart }
        let totalCleanedGB = periodCleanups.reduce(0.0) { $0 + $1.gb }

        // The disk was fuller before cleanups — estimate start point
        let startGB = currentGB + totalCleanedGB

        // Build daily points — flat line from startGB, dropping at each real cleanup
        var points: [TrendPoint] = []
        var runningGB = startGB

        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -(days - 1 - i), to: now)!

            // Check if any cleanups happened on this day
            let dayCleanups = periodCleanups.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            let dayCleanedGB = dayCleanups.reduce(0.0) { $0 + $1.gb }
            runningGB -= dayCleanedGB

            points.append(TrendPoint(id: i, date: date, gb: max(0, runningGB)))
        }

        trendData = points

        // Build real cleanup markers from store
        var markers: [CleanupMarker] = []
        let uniqueDays = Dictionary(grouping: periodCleanups, by: { Calendar.current.startOfDay(for: $0.date) })
        for (idx, (day, dayItems)) in uniqueDays.sorted(by: { $0.key < $1.key }).enumerated() {
            let totalGB = dayItems.reduce(0.0) { $0 + $1.gb }
            // Find the matching trend point
            if let point = points.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
                markers.append(CleanupMarker(id: idx, date: point.date, gb: point.gb))
            }
            _ = totalGB // used for marker label if needed
        }
        cleanupMarkers = markers

        // Real delta
        if totalCleanedGB > 0.1 {
            trendDelta = String(format: "\u{2212} %.1f GB cleaned this period", totalCleanedGB)
        } else if store.items.isEmpty {
            trendDelta = "No cleanups yet"
        } else {
            trendDelta = "No change this period"
        }
    }

    // MARK: - Recommendations

    struct CleanupRecommendation: Identifiable {
        let id: String; let name: String; let description: String
        let icon: String; var sizeLabel: String; let isRecommended: Bool
    }

    @Published var recommendations: [CleanupRecommendation] = []

    private var cancellables = Set<AnyCancellable>()
    @Published public var isScanning = false

    // MARK: - Init

    public init() {
        userName = NSFullUserName().components(separatedBy: " ").first ?? "there"

        // Step 1: Volume stats — instant
        refreshVolumeStats()

        // Listen for cleanup events
        CleanedItemStore.shared.objectWillChange
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAfterClean() }
            .store(in: &cancellables)

        // Listen for Smart Scan trigger
        NotificationCenter.default.publisher(for: .init("PareSmartScanRequested"))
            .sink { [weak self] _ in self?.runSmartScan() }
            .store(in: &cancellables)

        // Initial categories and recommendations (shown immediately)
        categories = [
            .init(id: "used", name: "Used", bytes: usedBytes, color: CategoryColor.apps)
        ]
        recommendations = [
            .init(id: "dup",   name: "Duplicate files",    description: "Duplicate files across Downloads, Documents, and Desktop.",  icon: "doc.on.doc",      sizeLabel: "Scanning...", isRecommended: true),
            .init(id: "dev",   name: "Xcode derived data", description: "Old build artefacts and simulator data.",                    icon: "chevron.left.forwardslash.chevron.right", sizeLabel: "Scanning...", isRecommended: true),
            .init(id: "cache", name: "System caches",      description: "Safely regenerated. Includes browser and app caches.",        icon: "desktopcomputer", sizeLabel: "Scanning...", isRecommended: false),
            .init(id: "large", name: "Large old files",    description: "Files over 100 MB unopened in 6+ months.",                   icon: "doc.badge.arrow.up", sizeLabel: "Scanning...", isRecommended: false),
            .init(id: "app",   name: "Leftover app data",  description: "Caches and preferences from uninstalled apps.",              icon: "square.grid.3x1.below.line.grid.1x2", sizeLabel: "Scanning...", isRecommended: false),
            .init(id: "mail",  name: "Mail attachments",   description: "Re-downloadable. Safe to clear from local cache.",           icon: "envelope",        sizeLabel: "Scanning...", isRecommended: false),
        ]
        rebuildTrendData()

        // Step 2: load directory sizes in background
        loadDirectorySizes()
    }

    /// Re-read volume stats (instant)
    private func refreshVolumeStats() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free  = (attrs[.systemFreeSize] as? Int64) ?? 0
            capacityBytes = total
            usedBytes = total - free
        }
    }

    /// Called when CleanedItemStore changes
    private func refreshAfterClean() {
        refreshVolumeStats()
        rebuildTrendData()
        lastScanLabel = "Last scan: just now"
        loadDirectorySizes()
    }

    /// Smart Scan: re-scans everything with progress, updates dashboard in-place
    public func runSmartScan() {
        isScanning = true
        lastScanLabel = "Scanning now..."
        // Reset recommendations to show scanning state
        for i in recommendations.indices {
            recommendations[i].sizeLabel = "Scanning..."
        }
        loadDirectorySizes()
    }

    private func loadDirectorySizes() {
        let vm = self
        let home = FileManager.default.homeDirectoryForCurrentUser
        let scan = DiskScanProgress.shared
        let showProgress = isLoading // only show progress bar on first load

        DispatchQueue.global(qos: .userInitiated).async {
            if showProgress { scan.start(total: 10) }

            if showProgress { scan.update(task: "Scanning caches...") }
            let caches    = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Caches"))
            if showProgress { scan.update(task: "Scanning logs...") }
            let logs      = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Logs"))
            if showProgress { scan.update(task: "Scanning downloads...") }
            let downloads = SystemStorageProvider.directorySize(home.appendingPathComponent("Downloads"))
            if showProgress { scan.update(task: "Scanning mail...") }
            let mail      = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Mail"))
            if showProgress { scan.update(task: "Scanning documents...") }
            let docs      = SystemStorageProvider.directorySize(home.appendingPathComponent("Documents"))
            if showProgress { scan.update(task: "Scanning movies...") }
            let movies    = SystemStorageProvider.directorySize(home.appendingPathComponent("Movies"))
            if showProgress { scan.update(task: "Scanning music & photos...") }
            let music     = SystemStorageProvider.directorySize(home.appendingPathComponent("Music"))
            let pictures  = SystemStorageProvider.directorySize(home.appendingPathComponent("Pictures"))
            if showProgress { scan.update(task: "Scanning developer tools...") }
            let developer = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Developer"))
            if showProgress { scan.update(task: "Scanning applications...") }
            let apps      = SystemStorageProvider.directorySize(URL(fileURLWithPath: "/Applications"))

            let media = movies + music + pictures
            let sysJunk = caches + logs

            DispatchQueue.main.async {
                vm.refreshVolumeStats()
                let used = vm.usedBytes
                let known = apps + docs + media + developer
                let sys = max(0, used - known)
                let other = max(0, used - apps - docs - media - sys)

                // Reclaimable = all cleanup categories combined
                vm.reclaimableBytes = sysJunk + downloads + developer + mail
                vm.reclaimableCategoryCount = [sysJunk, downloads, developer, mail].filter { $0 > 1_000_000 }.count

                vm.categories = [
                    .init(id: "apps",   name: "Apps & Data", bytes: apps,  color: CategoryColor.apps),
                    .init(id: "docs",   name: "Documents",   bytes: docs,  color: CategoryColor.documents),
                    .init(id: "media",  name: "Media",       bytes: media, color: CategoryColor.media),
                    .init(id: "system", name: "System",      bytes: sys,   color: CategoryColor.system),
                    .init(id: "other",  name: "Other",       bytes: other, color: CategoryColor.other),
                ]

                let fmt = { (b: Int64) -> String in
                    let gb = Double(b) / 1_073_741_824.0
                    if gb >= 1.0 { return String(format: "%.1f GB", gb) }
                    let mb = Double(b) / 1_000_000.0
                    if mb >= 1.0 { return String(format: "%.0f MB", mb) }
                    return String(format: "%.0f KB", Double(b) / 1_000.0)
                }
                vm.recommendations = [
                    .init(id: "dev",   name: "Xcode derived data", description: "Old build artefacts and simulator data.",                    icon: "chevron.left.forwardslash.chevron.right", sizeLabel: fmt(developer), isRecommended: developer > 1_000_000_000),
                    .init(id: "cache", name: "System caches",      description: "Safely regenerated. Includes browser and app caches.",        icon: "desktopcomputer", sizeLabel: fmt(sysJunk),   isRecommended: sysJunk > 500_000_000),
                    .init(id: "dl",    name: "Downloads",          description: "Old installers, archives, and attachments.",                  icon: "arrow.down.circle", sizeLabel: fmt(downloads), isRecommended: downloads > 1_000_000_000),
                    .init(id: "mail",  name: "Mail attachments",   description: "Re-downloadable. Safe to clear from local cache.",           icon: "envelope",        sizeLabel: fmt(mail),      isRecommended: mail > 500_000_000),
                    .init(id: "large", name: "Large old files",    description: "Files over 100 MB unopened in 6+ months.",                   icon: "doc.badge.arrow.up", sizeLabel: "Scan needed",  isRecommended: false),
                    .init(id: "app",   name: "Leftover app data",  description: "Caches and preferences from uninstalled apps.",              icon: "square.grid.3x1.below.line.grid.1x2", sizeLabel: "Scan needed",  isRecommended: false),
                ]
                vm.rebuildTrendData()
                vm.isLoading = false
                vm.isScanning = false
                vm.isLoading = false
                vm.lastScanLabel = "Last scan: just now"
                if showProgress { scan.finish() }
            }
        }
    }
}
