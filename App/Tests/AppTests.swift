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

    func testCoordinatorStartScanSwitchesRoute() {
        let c = AppCoordinator()
        c.startScan()
        XCTAssertEqual(c.route, .scan)
    }

    func testSystemStorageProviderReturnsNonZeroCapacity() {
        let snap = SystemStorageProvider.snapshot()
        XCTAssertGreaterThan(snap.totalCapacity, 0, "Volume total capacity should be > 0")
        XCTAssertGreaterThan(snap.availableBytes, 0, "Available bytes should be > 0")
        XCTAssertLessThan(snap.usedBytes, snap.totalCapacity, "Used should be less than total")
    }
}
