// Helper/Tests/HelperTests.swift

import XCTest
@testable import HelperLib
@testable import PareKit

final class HelperTests: XCTestCase {

    // ── Protected paths ───────────────────────────────────────────────
    func testSystemPathsAreProtected() {
        let cases = [
            "/System/Library/Caches",
            "/usr/bin/ls",
            "/Library/Apple/Library/Bundles",
            "/private/var/db/dyld/dyld_shared_cache",
        ]
        for path in cases {
            XCTAssertTrue(ProtectedPaths.isProtected(URL(fileURLWithPath: path)),
                "Expected \(path) to be protected.")
        }
    }

    func testCommonUserPathsAreNotProtected() {
        let cases = [
            "/Users/jumoke/Downloads/foo.dmg",
            "/Users/jumoke/Library/Caches/com.spotify.client",
        ]
        for path in cases {
            XCTAssertFalse(ProtectedPaths.isProtected(URL(fileURLWithPath: path)),
                "Expected \(path) to NOT be protected.")
        }
    }

    // ── Recovery store migrations apply cleanly ───────────────────────
    func testRecoveryStoreInitMigratesSchema() {
        let store = RecoveryStore()
        XCTAssertNotNil(store)
        // Listing an empty store returns an empty array, not an error.
        XCTAssertEqual((try? store.list())?.count, 0)
    }
}
