// Helper/Sources/Scanners/MailScanner.swift
//
// FR-08 — Apple Mail downloads / attachments cache and stale envelope index.

import Foundation
import PareKit

public struct MailScanner: Scanner {
    public let category: PareKit.Category = .mailCache
    public init() {}

    public func scan(
        options: ScanOptions,
        progress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> [ScanItem] {
        // TODO(P3): walk ~/Library/Mail/V*/{account}/.../Attachments and
        // ~/Library/Mail/V*/MailData; never touch the .mbox files themselves.
        return []
    }
}
