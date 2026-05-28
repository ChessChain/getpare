// Helper/Sources/Scanners/DeveloperScanner.swift
//
// FR-09 — Xcode DerivedData, unused simulators, archives, node_modules.
// Premium feature: deep simulator cleanup (BR-07 / pricing).

import Foundation
import PareKit

public struct DeveloperScanner: Scanner {
    public let category: PareKit.Category = .developerJunk
    public init() {}

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        // TODO(P3): ~/Library/Developer/Xcode/{DerivedData, Archives},
        // simctl list runtimes (unused via xcrun), node_modules detection
        // by missing package-lock recency.
        return []
    }
}
