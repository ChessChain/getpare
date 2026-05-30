// Helper/Sources/Engine/HashIndex.swift
//
// In-memory hash index used by the duplicate scanner. Not persisted by
// default — duplicates are recomputed on every scan to reflect filesystem
// reality.
//
// Algorithm selection per ADR-0005:
//   - SHA-256 for files ≤ `blake3Threshold`
//   - BLAKE3 for larger files (correctness-equivalent, ~5× faster on big inputs)
//
// BLAKE3 is NOT yet wired up — there's no first-party Apple BLAKE3, and a
// stable Swift package needs an explicit dep decision. Until then both
// branches call SHA-256; behaviour is correct, just slower than NFR-01
// targets on terabyte-scale media libraries. The `prefersBlake3(for:)` and
// `blake3(_:)` seam below is where a real implementation drops in.

import Foundation
import CryptoKit

public actor HashIndex {
    public enum Algorithm: Sendable, Equatable { case sha256, blake3 }

    /// Files strictly larger than this would prefer BLAKE3 per ADR-0005.
    public static let blake3Threshold: Int64 = 100 * 1024 * 1024

    private var index: [String: [URL]] = [:]   // hash → URLs

    public init() {}

    public func add(_ url: URL, hash: String) {
        index[hash, default: []].append(url)
    }

    public func duplicateGroups() -> [[URL]] {
        index.values.filter { $0.count > 1 }.map { $0 }
    }

    /// Hash a file using the algorithm appropriate for its size.
    /// Runs on a dedicated concurrent I/O queue so multiple files can hash
    /// in parallel without blocking the cooperative pool.
    public static func hash(_ url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            Self.ioQueue.async {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                    let size = (attrs[.size] as? Int64) ?? 0
                    let digest: String =
                        Self.prefersBlake3(forSize: size)
                            ? try Self.blake3(url)
                            : try Self.sha256(url)
                    cont.resume(returning: digest)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// Which algorithm would `hash(_:)` use for a file of this size?
    /// Exposed so callers (and tests) can log the algorithm in use.
    public static func algorithm(forSize size: Int64) -> Algorithm {
        prefersBlake3(forSize: size) ? .blake3 : .sha256
    }

    static func prefersBlake3(forSize size: Int64) -> Bool {
        size > blake3Threshold
    }

    // MARK: - Implementations

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

    /// BLAKE3 entry point. This is the single function to replace once a
    /// vetted Swift BLAKE3 package is added to Package.swift. Until then it
    /// falls through to SHA-256 — the hash is still correct, just not the
    /// faster algorithm ADR-0005 prescribes. A future implementation can
    /// keep this signature exactly and the rest of the codebase is unaffected.
    private static func blake3(_ url: URL) throws -> String {
        // TODO(ADR-0005): swap in a real BLAKE3 implementation here.
        // Candidate Swift packages need a dep decision (URL pinning, audit).
        try sha256(url)
    }
}
