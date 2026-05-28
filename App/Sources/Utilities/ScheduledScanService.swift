// App/Sources/Utilities/ScheduledScanService.swift
//
// Background scan timer — reads schedule from SettingsStore.
// Triggers a full rescan at the configured interval.

import Foundation
import Combine

public final class ScheduledScanService {
    public static let shared = ScheduledScanService()

    private var timer: AnyCancellable?
    private let defaults = UserDefaults.standard
    private let lastScanKey = "pare.scheduled.lastScan"

    private init() {
        setupTimer()
        // Re-setup when schedule setting changes
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.setupTimer()
        }
    }

    private func setupTimer() {
        timer?.cancel()
        let schedule = SettingsStore.shared.scheduledScans
        guard schedule != "Off" else { return }

        let interval: TimeInterval
        switch schedule {
        case "Daily":   interval = 86400
        case "Weekly":  interval = 604800
        case "Monthly": interval = 2592000
        default: return
        }

        // Check if enough time has passed since last scan
        let lastScan = defaults.object(forKey: lastScanKey) as? Date ?? .distantPast
        let elapsed = -lastScan.timeIntervalSinceNow
        let delay = max(60, interval - elapsed) // at least 1 min

        timer = Timer.publish(every: delay, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                self?.runScheduledScan()
                // Setup recurring
                self?.timer = Timer.publish(every: interval, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in self?.runScheduledScan() }
            }
    }

    private func runScheduledScan() {
        defaults.set(Date(), forKey: lastScanKey)
        // Trigger the dashboard smart scan
        NotificationCenter.default.post(name: .init("PareSmartScanRequested"), object: nil)

        // Notify when complete (after a delay to let scan finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            let reclaimable = ByteCountFormatter.string(fromByteCount: SystemStorageProvider.estimateReclaimable(), countStyle: .file)
            NotificationService.shared.notifyScanComplete(reclaimable: reclaimable)
        }
    }
}
