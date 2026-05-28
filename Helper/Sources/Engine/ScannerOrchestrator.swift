// Helper/Sources/Engine/ScannerOrchestrator.swift
//
// Runs every requested Scanner. Scanners are independent unless they
// share an index (e.g. the hash index used by Duplicates / Mail dedup),
// in which case the orchestrator runs them in dependency order.

import Foundation
import PareKit

public actor ScannerOrchestrator {

    private let log = PareLogger(.helper, category: "orchestrator")
    private var activeScans: [ScanHandle: ScanRun] = [:]

    private struct ScanRun {
        var task: Task<[ScanItem], Error>
        var progress: ScanProgress
        var results: [ScanItem]
    }

    public init() {}

    public func startScan(options: ScanOptions) throws -> ScanHandle {
        let handle = ScanHandle()
        let scanners: [Scanner] = options.categories.sorted(by: { $0.rawValue < $1.rawValue }).map { c in
            switch c {
            case .systemJunk:    return SystemJunkScanner()
            case .duplicate:     return DuplicateScanner()
            case .largeFile:     return LargeFileScanner()
            case .uninstaller:   return UninstallerScanner()
            case .mailCache:     return MailScanner()
            case .developerJunk: return DeveloperScanner()
            default:             return SystemJunkScanner() // TODO: downloads/photos/startup
            }
        }

        let log = log
        let task = Task<[ScanItem], Error> {
            var collected: [ScanItem] = []
            for (idx, scanner) in scanners.enumerated() {
                try Task.checkCancellation()
                log.info("Running \(scanner.category.rawValue) (\(idx + 1)/\(scanners.count))")
                let items = try await scanner.scan(options: options) { _ in }
                collected.append(contentsOf: items)

                // Update stored results and progress after each scanner completes.
                let bytesFound = collected.reduce(Int64(0)) { $0 + $1.bytes }
                self.updateRun(
                    handle: handle,
                    results: collected,
                    progress: ScanProgress(
                        percent: Double(idx + 1) / Double(scanners.count),
                        currentTask: "Scanned \(scanner.category.displayName)",
                        currentPath: "",
                        filesScanned: collected.count,
                        bytesFoundSoFar: bytesFound,
                        estimatedSecondsLeft: nil
                    )
                )
            }
            return collected
        }

        activeScans[handle] = ScanRun(
            task: task,
            progress: ScanProgress(percent: 0, currentTask: "Starting", currentPath: "",
                                   filesScanned: 0, bytesFoundSoFar: 0, estimatedSecondsLeft: nil),
            results: []
        )
        return handle
    }

    private func updateRun(handle: ScanHandle, results: [ScanItem], progress: ScanProgress) {
        activeScans[handle]?.results = results
        activeScans[handle]?.progress = progress
    }

    public func cancel(handle: ScanHandle) -> Bool {
        guard let run = activeScans[handle] else { return false }
        run.task.cancel()
        activeScans.removeValue(forKey: handle)
        return true
    }

    public func progress(for handle: ScanHandle) -> ScanProgress? {
        activeScans[handle]?.progress
    }

    public func results(for handle: ScanHandle) -> [ScanItem] {
        activeScans[handle]?.results ?? []
    }
}
