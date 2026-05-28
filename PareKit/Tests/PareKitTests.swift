// PareKit/Tests/PareKitTests.swift

import XCTest
@testable import PareKit

final class PareKitTests: XCTestCase {

    func testCategoryRoundTripsThroughJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for c in Category.allCases {
            let data = try encoder.encode(c)
            let back = try decoder.decode(Category.self, from: data)
            XCTAssertEqual(c, back)
        }
    }

    func testScanItemRoundTrips() throws {
        let item = ScanItem(
            path: URL(fileURLWithPath: "/tmp/foo"),
            category: .duplicate,
            bytes: 1_234,
            lastModified: Date(timeIntervalSince1970: 1_700_000_000),
            lastAccessed: Date(timeIntervalSince1970: 1_700_001_000),
            contentHash: "deadbeef",
            riskLevel: .safe,
            groupID: UUID(),
            metadata: ["app": "WhatsApp"]
        )
        let data = try JSONEncoder().encode(item)
        let back = try JSONDecoder().decode(ScanItem.self, from: data)
        XCTAssertEqual(item, back)
    }

    func testHelperServiceNameMatchesLaunchPlist() {
        XCTAssertEqual(PareIPC.helperServiceName, "com.clearpath.pare.helper",
            "Update the helper's launchd plist if you change this.")
    }

    func testDefaultScanOptionsCoverAllCategories() {
        let opts = ScanOptions()
        XCTAssertEqual(opts.categories, Set(Category.allCases))
        XCTAssertEqual(opts.largeFileThresholdBytes, 100 * 1024 * 1024)
        XCTAssertFalse(opts.deepScan)
    }
}
