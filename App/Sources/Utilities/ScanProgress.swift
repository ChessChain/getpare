// App/Sources/Utilities/DiskScanProgress.swift
//
// Shared singleton that tracks background directory scan progress.
// Both Dashboard and Insights observe this for progress UI.

import Foundation
import Combine

public final class DiskScanProgress: ObservableObject {
    public static let shared = DiskScanProgress()

    @Published public var isScanning: Bool = false
    @Published public var progress: Double = 0        // 0.0 ... 1.0
    @Published public var currentTask: String = ""
    @Published public var completedItems: Int = 0
    @Published public var totalItems: Int = 10         // number of directories to scan

    private init() {}

    public func start(total: Int) {
        DispatchQueue.main.async {
            self.isScanning = true
            self.progress = 0
            self.completedItems = 0
            self.totalItems = total
            self.currentTask = "Preparing scan..."
        }
    }

    public func update(task: String) {
        DispatchQueue.main.async {
            self.currentTask = task
            self.completedItems += 1
            self.progress = min(1.0, Double(self.completedItems) / Double(self.totalItems))
        }
    }

    public func finish() {
        DispatchQueue.main.async {
            self.progress = 1.0
            self.currentTask = "Complete"
            // Brief delay before hiding so user sees 100%
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.isScanning = false
            }
        }
    }
}
