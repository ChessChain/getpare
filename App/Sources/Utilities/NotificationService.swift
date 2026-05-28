// App/Sources/Utilities/NotificationService.swift
//
// macOS Notification Center integration for:
// - Low disk space alerts
// - Scan completion banners
// - Recovery Bin expiry warnings

import Foundation
import UserNotifications
import Combine

public final class NotificationService {
    public static let shared = NotificationService()

    private var cancellables = Set<AnyCancellable>()
    private let center = UNUserNotificationCenter.current()

    private init() {
        requestPermission()
        setupMonitors()
    }

    // MARK: - Permission

    private func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Monitors

    private func setupMonitors() {
        // Monitor cleanup store for bin expiry
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkBinExpiry()
                self?.checkDiskSpace()
            }
            .store(in: &cancellables)
    }

    // MARK: - Low Disk Space

    func checkDiskSpace() {
        guard SettingsStore.shared.lowSpaceAlert != "Off" else { return }

        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64,
              let free = attrs[.systemFreeSize] as? Int64,
              total > 0 else { return }

        let freePercent = Double(free) / Double(total) * 100
        let threshold: Double
        switch SettingsStore.shared.lowSpaceAlert {
        case "Below 10%": threshold = 10
        case "Below 15%": threshold = 15
        case "Below 25%": threshold = 25
        default: return
        }

        if freePercent < threshold {
            let freeGB = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
            send(
                id: "low-disk-space",
                title: "Low disk space",
                body: "Only \(freeGB) free (\(Int(freePercent))%). Open Pare to reclaim space.",
                category: "LOW_SPACE"
            )
        }
    }

    // MARK: - Scan Completion

    func notifyScanComplete(reclaimable: String) {
        guard SettingsStore.shared.scanCompletionNotify else { return }
        send(
            id: "scan-complete-\(Date().timeIntervalSince1970)",
            title: "Scan complete",
            body: "\(reclaimable) of reclaimable space found. Open Pare to review.",
            category: "SCAN_COMPLETE"
        )
    }

    // MARK: - Recovery Bin Expiry

    func checkBinExpiry() {
        guard SettingsStore.shared.weeklyDigest else { return }
        let store = CleanedItemStore.shared
        let expiringSoon = store.items.filter { $0.daysLeft <= 3 && $0.daysLeft > 0 }
        guard !expiringSoon.isEmpty else { return }

        let totalSize = ByteCountFormatter.string(fromByteCount: expiringSoon.reduce(0) { $0 + $1.bytes }, countStyle: .file)
        send(
            id: "bin-expiry",
            title: "Recovery Bin items expiring",
            body: "\(expiringSoon.count) items (\(totalSize)) will be permanently deleted within 3 days. Restore them now if needed.",
            category: "BIN_EXPIRY"
        )
    }

    // MARK: - Send

    private func send(id: String, title: String, body: String, category: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }
}
