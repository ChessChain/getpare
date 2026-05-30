// App/Sources/Views/Insights/InsightsViewModel.swift

import Foundation
import SwiftUI
import Combine

public final class InsightsViewModel: ObservableObject {

    private var cancellable: AnyCancellable?

    // MARK: - Stat Cards

    struct StatCard: Identifiable {
        let id: String
        let label: String
        var value: String
        var delta: String
        let isWarning: Bool
    }

    @Published var stats: [StatCard]

    // MARK: - Storage Over Time

    struct StoragePoint: Identifiable {
        let id: Int
        let date: Date
        let gb: Double
    }

    struct CleanupMarker: Identifiable {
        let id: Int
        let date: Date
        let gb: Double
        let label: String
    }

    @Published var storageOverTime: [StoragePoint]
    @Published var cleanupMarkers: [CleanupMarker]

    // MARK: - Donut

    struct DonutSegment: Identifiable {
        let id: String
        let name: String
        var gb: Double
        let color: Color
    }

    @Published var donutSegments: [DonutSegment]
    var donutTotal: Double { donutSegments.reduce(0) { $0 + $1.gb } }
    @Published var donutUsedLabel: String

    // MARK: - Top Reclaims

    struct ReclaimEntry: Identifiable {
        let id: String
        let date: String
        let category: String
        let detail: String
        var amount: String
    }

    @Published var topReclaims: [ReclaimEntry]

    // MARK: - Heatmap

    @Published var heatmapData: [[Int]] = Array(repeating: Array(repeating: 0, count: 12), count: 7)
    let heatmapDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    // MARK: - Init

    public init() {
        // Volume stats — instant
        var usedGB = 455.0
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free  = (attrs[.systemFreeSize] as? Int64) ?? 0
            usedGB = Double(total - free) / 1_073_741_824.0
        }

        // Pre-populate stats immediately with volume data
        stats = [
            .init(id: "reclaimed", label: "RECLAIMED (ALL-TIME)", value: "Scanning...",  delta: "Calculating...", isWarning: false),
            .init(id: "scans",     label: "SCANS RUN",            value: "1",            delta: "First scan",    isWarning: false),
            .init(id: "avg",       label: "AVG PER CLEANUP",      value: "Scanning...",  delta: "Calculating...", isWarning: false),
            .init(id: "stale",     label: "DAYS SINCE LAST SCAN", value: "0",            delta: "Up to date",    isWarning: false),
        ]

        // Pre-populate donut with single "Used" segment
        donutUsedLabel = "\(Int(usedGB)) GB"
        donutSegments = [
            .init(id: "used", name: "Used", gb: usedGB, color: CategoryColor.apps)
        ]

        // Pre-populate trend as flat line at current usage
        let cal = Calendar.current
        let now = Date()
        storageOverTime = stride(from: 0, to: 365, by: 3).enumerated().map { idx, i in
            let date = cal.date(byAdding: .day, value: -(364 - i), to: now)!
            return StoragePoint(id: idx, date: date, gb: usedGB)
        }
        cleanupMarkers = []

        // Pre-populate reclaims with placeholders
        topReclaims = [
            .init(id: "dev",   date: "Today", category: "Developer Junk", detail: "Xcode DerivedData + caches",   amount: "Scanning..."),
            .init(id: "dl",    date: "Today", category: "Downloads",      detail: "Old installers + archives",    amount: "Scanning..."),
            .init(id: "cache", date: "Today", category: "System Junk",    detail: "Browser + app caches + logs",  amount: "Scanning..."),
            .init(id: "mail",  date: "Today", category: "Mail Cleanup",   detail: "Attachments & envelope index", amount: "Scanning..."),
            .init(id: "total", date: "Today", category: "Total reclaimable", detail: "Across all categories",     amount: "Scanning..."),
        ]

        // Listen for cleanup events
        cancellable = CleanedItemStore.shared.objectWillChange
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadRealData()
            }

        loadRealData()
    }

    private func loadRealData() {
        let vm = self
        let home = FileManager.default.homeDirectoryForCurrentUser

        // Volume stats — always real
        var usedGB = 0.0
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free  = (attrs[.systemFreeSize] as? Int64) ?? 0
            usedGB = Double(total - free) / 1_073_741_824.0
        }
        let cal = Calendar.current
        let now = Date()

        DispatchQueue.global(qos: .userInitiated).async {
            let apps      = SystemStorageProvider.directorySize(URL(fileURLWithPath: "/Applications"))
            let docs      = SystemStorageProvider.directorySize(home.appendingPathComponent("Documents"))
            let downloads = SystemStorageProvider.directorySize(home.appendingPathComponent("Downloads"))
            let movies    = SystemStorageProvider.directorySize(home.appendingPathComponent("Movies"))
            let music     = SystemStorageProvider.directorySize(home.appendingPathComponent("Music"))
            let pictures  = SystemStorageProvider.directorySize(home.appendingPathComponent("Pictures"))
            let developer = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Developer"))
            let caches    = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Caches"))
            let logs      = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Logs"))
            let mail      = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Mail"))

            let media = movies + music + pictures
            let sysJunk = caches + logs
            let reclaimable = sysJunk + downloads + developer + mail

            let reclaimGB = Double(reclaimable) / 1_073_741_824.0
            let devGB     = Double(developer) / 1_073_741_824.0
            let dlGB      = Double(downloads) / 1_073_741_824.0
            let cacheGB   = Double(sysJunk) / 1_073_741_824.0
            let mailGB    = Double(mail) / 1_073_741_824.0
            let appsGB    = Double(apps) / 1_073_741_824.0
            let docsGB    = Double(docs) / 1_073_741_824.0
            let mediaGB   = Double(media) / 1_073_741_824.0
            let sysGB     = max(0, usedGB - appsGB - docsGB - mediaGB - devGB)
            let otherGB   = max(0, usedGB - appsGB - docsGB - mediaGB - sysGB)

            // Build real trend from cleanup history
            let store = CleanedItemStore.shared
            let storeItems = store.items
            let totalCleanedGB = Double(store.totalBytes) / 1_073_741_824.0
            let cleanedCount = store.totalCount
            let startGB = usedGB + totalCleanedGB

            var points: [StoragePoint] = []
            var runningGB = startGB
            var idx = 0
            for i in stride(from: 0, to: 365, by: 3) {
                let date = cal.date(byAdding: .day, value: -(364 - i), to: now)!
                let dayCleanups = storeItems.filter { cal.isDate($0.cleanedDate, inSameDayAs: date) }
                let dayCleanedGB = dayCleanups.reduce(0.0) { $0 + Double($1.bytes) / 1_073_741_824.0 }
                runningGB -= dayCleanedGB
                points.append(StoragePoint(id: idx, date: date, gb: max(0, runningGB)))
                idx += 1
            }

            // Real cleanup markers from store
            var markers: [CleanupMarker] = []
            let uniqueDays = Dictionary(grouping: storeItems, by: { cal.startOfDay(for: $0.cleanedDate) })
            for (mIdx, (day, dayItems)) in uniqueDays.sorted(by: { $0.key < $1.key }).enumerated() {
                let totalGB = dayItems.reduce(0.0) { $0 + Double($1.bytes) / 1_073_741_824.0 }
                if let point = points.min(by: { abs($0.date.timeIntervalSince(day)) < abs($1.date.timeIntervalSince(day)) }) {
                    markers.append(.init(id: mIdx, date: point.date, gb: point.gb, label: String(format: "\u{2212}%.1f GB", totalGB)))
                }
            }

            // Real heatmap from cleanup history (7 days x 12 weeks)
            var heatmap = Array(repeating: Array(repeating: 0, count: 12), count: 7)
            for item in storeItems {
                let weeksAgo = Int(-item.cleanedDate.timeIntervalSinceNow / (7 * 86400))
                let weekCol = 11 - min(11, weeksAgo)
                let dayRow = (cal.component(.weekday, from: item.cleanedDate) + 5) % 7 // Mon=0
                let bytesGB = Double(item.bytes) / 1_073_741_824.0
                let intensity = bytesGB > 5 ? 3 : (bytesGB > 1 ? 2 : 1)
                heatmap[dayRow][weekCol] = max(heatmap[dayRow][weekCol], intensity)
            }

            let fmt = { (v: Double) -> String in
                if v >= 1.0 { return String(format: "%.1f GB", v) }
                if v >= 0.001 { return String(format: "%.0f MB", v * 1024) }
                return "0 KB"
            }

            // Days since last cleanup
            let daysSinceClean: String
            if let latest = storeItems.first {
                let days = Int(-latest.cleanedDate.timeIntervalSinceNow / 86400)
                daysSinceClean = days == 0 ? "Today" : "\(days)"
            } else {
                daysSinceClean = "Never"
            }

            // Average per cleanup
            let avgGB = cleanedCount > 0 ? totalCleanedGB / Double(cleanedCount) : 0

            DispatchQueue.main.async {
                if cleanedCount > 0 {
                    // Has cleanup history — show real stats
                    vm.stats = [
                        .init(id: "reclaimed", label: "RECLAIMED (ALL-TIME)", value: fmt(totalCleanedGB), delta: String(format: "%.1f GB still reclaimable", reclaimGB), isWarning: false),
                        .init(id: "scans",     label: "CLEANUPS",             value: "\(cleanedCount)",    delta: "\(cleanedCount) total",       isWarning: false),
                        .init(id: "avg",       label: "AVG PER CLEANUP",      value: fmt(avgGB),           delta: devGB > cacheGB ? String(format: "Largest: Developer %.1f GB", devGB) : String(format: "Largest: Caches %.1f GB", cacheGB), isWarning: false),
                        .init(id: "stale",     label: "LAST CLEANUP",         value: daysSinceClean,       delta: "Up to date", isWarning: false),
                    ]
                } else {
                    // No history yet — show reclaimable potential
                    vm.stats = [
                        .init(id: "reclaimable", label: "RECLAIMABLE",       value: fmt(reclaimGB),  delta: "Space you can free up now", isWarning: false),
                        .init(id: "disk",        label: "DISK USED",         value: "\(Int(usedGB)) GB", delta: String(format: "%.0f%% of disk", usedGB / max(1, usedGB + Double((try? FileManager.default.attributesOfFileSystem(forPath: "/")[.systemFreeSize] as? Int64) ?? 0) / 1_073_741_824) * 100), isWarning: usedGB > 400),
                        .init(id: "largest",     label: "LARGEST CATEGORY",  value: devGB > cacheGB ? "Developer" : "Caches", delta: fmt(max(devGB, cacheGB)), isWarning: false),
                        .init(id: "cleanup",     label: "CLEANUPS",          value: "0",              delta: "Run your first cleanup to start tracking", isWarning: true),
                    ]
                }

                vm.storageOverTime = points
                vm.cleanupMarkers = markers
                vm.heatmapData = heatmap

                vm.donutUsedLabel = "\(Int(usedGB)) GB"
                vm.donutSegments = [
                    .init(id: "apps",  name: "Apps",      gb: appsGB,  color: CategoryColor.apps),
                    .init(id: "docs",  name: "Documents", gb: docsGB,  color: CategoryColor.documents),
                    .init(id: "media", name: "Media",     gb: mediaGB, color: CategoryColor.media),
                    .init(id: "sys",   name: "System",    gb: sysGB,   color: CategoryColor.system),
                    .init(id: "other", name: "Other",     gb: otherGB, color: CategoryColor.other),
                ]

                // Top reclaims — show real cleanup history or reclaimable potential
                if cleanedCount > 0 {
                    // Build from actual cleanup history grouped by category
                    let catGroups = Dictionary(grouping: storeItems, by: \.category)
                    var reclaims: [ReclaimEntry] = []
                    for (cat, items) in catGroups.sorted(by: { $0.value.reduce(0) { $0 + $1.bytes } > $1.value.reduce(0) { $0 + $1.bytes } }).prefix(5) {
                        let total = items.reduce(0.0) { $0 + Double($1.bytes) / 1_073_741_824.0 }
                        let dateFmt = DateFormatter()
                        dateFmt.dateFormat = "d MMM"
                        let latestDate = items.max(by: { $0.cleanedDate < $1.cleanedDate })?.cleanedDate ?? Date()
                        reclaims.append(.init(id: cat, date: dateFmt.string(from: latestDate), category: cat, detail: "\(items.count) items cleaned", amount: fmt(total)))
                    }
                    vm.topReclaims = reclaims
                } else {
                    // No history — show what CAN be reclaimed
                    vm.topReclaims = [
                        .init(id: "dev",   date: "Now", category: "Developer Junk", detail: "Xcode DerivedData + caches",   amount: fmt(devGB)),
                        .init(id: "dl",    date: "Now", category: "Downloads",      detail: "Old installers + archives",    amount: fmt(dlGB)),
                        .init(id: "cache", date: "Now", category: "System Junk",    detail: "Browser + app caches + logs",  amount: fmt(cacheGB)),
                        .init(id: "mail",  date: "Now", category: "Mail Cleanup",   detail: "Attachments & envelope index", amount: fmt(mailGB)),
                        .init(id: "total", date: "Now", category: "Total reclaimable", detail: "Across all categories",     amount: fmt(reclaimGB)),
                    ]
                }
            }
        }
    }
}
