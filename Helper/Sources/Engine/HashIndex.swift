// Helper/Sources/Engine/HashIndex.swift
//
// In-memory hash index used by the duplicate scanner. Not persisted by
// default — duplicates are recomputed on every scan to reflect filesystem
// reality. ADR-005: SHA-256 for files ≤100MB, BLAKE3 for larger.

import Foundation
import CryptoKit

public actor HashIndex {
    public enum Algorithm { case sha256, blake3 }

    private var index: [String: [URL]] = [:]   // hash → URLs

    public init() {}

    public func add(_ url: URL, hash: String) {
        index[hash, default: []].append(url)
    }

    public func duplicateGroups() -> [[URL]] {
        index.values.filter { $0.count > 1 }.map { $0 }
    }

    /// Hash a file using the appropriate algorithm for its size.
    /// Runs on a dedicated I/O thread to avoid blocking the cooperative pool.
    public static func hash(_ url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            Self.ioQueue.async {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                    let size = (attrs[.size] as? Int64) ?? 0
                    if size > 100 * 1024 * 1024 {
                        // TODO: switch to BLAKE3 (vendor or write Swift wrapper).
                        cont.resume(returning: try sha256(url))
                    } else {
                        cont.resume(returning: try sha256(url))
                    }
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private static let ioQueue = DispatchQueue(
        label: "com.clearpath.pare.hash-io",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
