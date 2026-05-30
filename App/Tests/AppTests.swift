// App/Tests/AppTests.swift

import XCTest
@testable import AppLib
@testable import PareKit

@MainActor
final class AppTests: XCTestCase {

    func testCoordinatorDefaultRouteIsDashboard() {
        let c = AppCoordinator()
        XCTAssertEqual(c.route, .dashboard)
    }

    func testCoordinatorStartScanPostsNotification() {
        let c = AppCoordinator()
        let exp = expectation(forNotification: .init("PareSmartScanRequested"), object: nil)
        c.startScan()
        wait(for: [exp], timeout: 1.0)
        // Smart Scan intentionally does not change the route — it broadcasts a
        // notification that the dashboard's view models listen for, and the
        // scan runs inline on whatever screen is open.
        XCTAssertEqual(c.route, .dashboard)
    }

    func testSystemStorageProviderReturnsNonZeroCapacity() {
        let snap = SystemStorageProvider.snapshot()
        XCTAssertGreaterThan(snap.totalCapacity, 0, "Volume total capacity should be > 0")
        XCTAssertGreaterThan(snap.availableBytes, 0, "Available bytes should be > 0")
        XCTAssertLessThan(snap.usedBytes, snap.totalCapacity, "Used should be less than total")
    }
}
