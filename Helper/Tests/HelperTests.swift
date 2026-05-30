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
            XCTAssertTrue(
                ProtectedPaths.isProtected(URL(fileURLWithPath: path)),
                "Expected \(path) to be protected."
            )
        }
    }

    func testCommonUserPathsAreNotProtected() {
        let cases = [
            "/Users/jumoke/Downloads/foo.dmg",
            "/Users/jumoke/Library/Caches/com.spotify.client",
        ]
        for path in cases {
            XCTAssertFalse(
                ProtectedPaths.isProtected(URL(fileURLWithPath: path)),
                "Expected \(path) to NOT be protected."
            )
        }
    }

    // ── Recovery store ────────────────────────────────────────────────

    /// Spins up a fresh RecoveryStore against an isolated temp directory.
    /// Each test gets its own — never touch the developer's real `~/Library`.
    private func makeStore() -> (store: RecoveryStore, base: URL) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-tests-\(UUID().uuidString)", isDirectory: true)
        return (RecoveryStore(baseDirectory: base), base)
    }

    func testRecoveryStoreInitMigratesSchema() throws {
        let (store, base) = makeStore()
        defer { try? FileManager.default.removeItem(at: base) }
        XCTAssertEqual(try store.list().count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("recovery.sqlite").path))
    }

    func testInsertAndListRoundtrip() throws {
        let (store, base) = makeStore()
        defer { try? FileManager.default.removeItem(at: base) }

        let scanID = UUID()
        let archiveDir = try store.archiveDirectory(for: scanID)
        let archived = archiveDir.appendingPathComponent("doc.txt")
        try "payload".write(to: archived, atomically: true, encoding: .utf8)

        let item = RecoveryItem(
            originalPath: URL(fileURLWithPath: "/tmp/doc.txt"),
            archivedPath: archived,
            bytes: 7,
            category: .systemJunk,
            removedAt: Date(),
            purgesAt: Date().addingTimeInterval(30 * 24 * 60 * 60),
            scanID: scanID
        )
        try store.insert(item)

        let listed = try store.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.bytes, 7)
        XCTAssertEqual(listed.first?.category, .systemJunk)
    }

    func testRestoreMovesArchivedFileToOriginalPath() throws {
        let (store, base) = makeStore()
        defer { try? FileManager.default.removeItem(at: base) }

        let scanID = UUID()
        let archiveDir = try store.archiveDirectory(for: scanID)
        let archived = archiveDir.appendingPathComponent("note.txt")
        let original = base.appendingPathComponent("restore-target/note.txt")
        try "hello".write(to: archived, atomically: true, encoding: .utf8)

        let item = RecoveryItem(
            originalPath: original,
            archivedPath: archived,
            bytes: 5,
            category: .downloads,
            removedAt: Date(),
            purgesAt: Date().addingTimeInterval(30 * 24 * 60 * 60),
            scanID: scanID
        )
        try store.insert(item)

        let report = try store.restore(itemIDs: [item.id])
        XCTAssertEqual(report.restoredCount, 1)
        XCTAssertTrue(report.conflicts.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        // Item is no longer 'available'.
        XCTAssertEqual(try store.list().count, 0)
    }

    func testRestoreWritesSuffixedCopyWhenOriginalExists() throws {
        let (store, base) = makeStore()
        defer { try? FileManager.default.removeItem(at: base) }

        let scanID = UUID()
        let archiveDir = try store.archiveDirectory(for: scanID)
        let archived = archiveDir.appendingPathComponent("doc.txt")
        let original = base.appendingPathComponent("conflict-target/doc.txt")
        try FileManager.default.createDirectory(
            at: original.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "newer".write(to: archived, atomically: true, encoding: .utf8)
        try "older".write(to: original, atomically: true, encoding: .utf8)

        let item = RecoveryItem(
            originalPath: original,
            archivedPath: archived,
            bytes: 5,
            category: .downloads,
            removedAt: Date(),
            purgesAt: Date().addingTimeInterval(30 * 24 * 60 * 60),
            scanID: scanID
        )
        try store.insert(item)

        let report = try store.restore(itemIDs: [item.id])
        XCTAssertEqual(report.restoredCount, 1)
        XCTAssertEqual(report.conflicts.count, 1)
        XCTAssertNotEqual(report.conflicts.first?.resolvedPath, original)
        XCTAssertTrue(report.conflicts.first?.resolvedPath.lastPathComponent.contains("(restored)") ?? false)
    }

    // ── LargeFileScanner ──────────────────────────────────────────────

    /// Lay down two files of given sizes under a fresh temp root.
    private func makeScannerFixture(small: Int, large: Int) throws -> (root: URL, smallURL: URL, largeURL: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-scanner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let smallURL = root.appendingPathComponent("small.bin")
        let largeURL = root.appendingPathComponent("big.bin")
        try Data(count: small).write(to: smallURL)
        try Data(count: large).write(to: largeURL)
        return (root, smallURL, largeURL)
    }

    func testLargeFileScannerReturnsOnlyFilesAboveThreshold() async throws {
        let (root, _, largeURL) = try makeScannerFixture(small: 100, large: 4 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: root) }

        let scanner = LargeFileScanner(roots: [root])
        let options = ScanOptions(
            categories: [.largeFile],
            largeFileThresholdBytes: 1 * 1024 * 1024,
            deepScan: false
        )
        let results = try await scanner.scan(options: options) { _ in }

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(
            results.first?.path.standardizedFileURL,
            largeURL.standardizedFileURL
        )
        XCTAssertEqual(results.first?.category, .largeFile)
        XCTAssertGreaterThanOrEqual(results.first?.bytes ?? 0, 4 * 1024 * 1024)
    }

    func testLargeFileScannerEmitsTerminalProgress() async throws {
        let (root, _, _) = try makeScannerFixture(small: 10, large: 10)
        defer { try? FileManager.default.removeItem(at: root) }

        actor ProgressCollector { var last: ScanProgress?
            func capture(_ p: ScanProgress) { last = p }
        }
        let collector = ProgressCollector()

        _ = try await LargeFileScanner(roots: [root])
            .scan(options: ScanOptions()) { progress in
                Task { await collector.capture(progress) }
            }
        // Give the detached Task time to flush.
        try await Task.sleep(nanoseconds: 50_000_000)

        let last = await collector.last
        XCTAssertEqual(last?.percent, 1.0)
        XCTAssertEqual(last?.estimatedSecondsLeft, 0)
    }

    func testLargeFileScannerRespectsCancellation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-cancel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // Drop a handful of files; we don't need many — cancellation hits on
        // every iteration of the file loop.
        for i in 0..<50 {
            try Data(count: 1024).write(to: root.appendingPathComponent("f-\(i).bin"))
        }

        let scanner = LargeFileScanner(roots: [root], progressEveryNFiles: 1)
        let task = Task<[ScanItem], Error> {
            try await scanner.scan(options: ScanOptions()) { _ in }
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected.
        }
    }

    // ── SystemJunkScanner ─────────────────────────────────────────────

    /// Builds a `~/Library/Caches`-shaped fixture so the SystemJunk scanner
    /// finds files under the expected subcategory paths.
    private func makeSystemJunkFixture() throws -> (root: URL, cachesDir: URL, logsDir: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-sysjunk-\(UUID().uuidString)", isDirectory: true)
        let caches = root.appendingPathComponent("Library/Caches", isDirectory: true)
        let logs = root.appendingPathComponent("Library/Logs", isDirectory: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return (root, caches, logs)
    }

    func testSystemJunkScannerFindsCachesAndLogs() async throws {
        let (root, caches, logs) = try makeSystemJunkFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        // Avoid `.app` in the directory name — FileManager.enumerator would
        // treat it as a bundle and `.skipsPackageDescendants` would skip it.
        let cacheFile = caches.appendingPathComponent("com.foo.client/Cache.db")
        let logFile = logs.appendingPathComponent("FooApp.log")
        try FileManager.default.createDirectory(
            at: cacheFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(count: 2_048).write(to: cacheFile)
        try Data(count: 4_096).write(to: logFile)

        let scanner = SystemJunkScanner(roots: [caches, logs])
        let results = try await scanner.scan(options: ScanOptions()) { _ in }

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.category == .systemJunk })
        XCTAssertEqual(Set(results.compactMap { $0.metadata["subcategory"] }), ["cache", "log"])
    }

    func testSystemJunkScannerTagsRecentFilesAsCaution() async throws {
        let (root, caches, _) = try makeSystemJunkFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        // Fresh file → caution. Default `Data.write` stamps `now`.
        let fresh = caches.appendingPathComponent("Recent.cache")
        try Data(count: 256).write(to: fresh)

        let results = try await SystemJunkScanner(roots: [caches])
            .scan(options: ScanOptions()) { _ in }
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.riskLevel, .caution)
    }

    func testSystemJunkScannerRespectsCancellation() async throws {
        let (root, caches, _) = try makeSystemJunkFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        for i in 0..<50 {
            try Data(count: 64).write(to: caches.appendingPathComponent("f-\(i).cache"))
        }
        let scanner = SystemJunkScanner(roots: [caches], progressEveryNFiles: 1)
        let task = Task<[ScanItem], Error> {
            try await scanner.scan(options: ScanOptions()) { _ in }
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected.
        }
    }

    // ── UninstallerScanner ───────────────────────────────────────────

    /// Build a minimal but enumerator-realistic `Foo.app` bundle.
    private func makeFakeApp(name: String, bundleID: String, in dir: URL, fileSize: Int) throws -> URL {
        let app = dir.appendingPathComponent("\(name).app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let macos = contents.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)

        let infoPlist = contents.appendingPathComponent("Info.plist")
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": name,
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try data.write(to: infoPlist)
        try Data(count: fileSize).write(to: macos.appendingPathComponent(name))
        return app
    }

    /// Build a temp `userHome` shaped like `~/` for residue/leftover tests.
    private func makeFakeUserHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-uninst-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    func testUninstallerScannerEnumeratesApps() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-uninst-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try makeFakeApp(name: "Foo", bundleID: "com.example.foo", in: root, fileSize: 2_048)
        _ = try makeFakeApp(name: "Bar", bundleID: "com.example.bar", in: root, fileSize: 4_096)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("NotAnApp"),
            withIntermediateDirectories: true
        )

        let home = try makeFakeUserHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let results = try await UninstallerScanner(
            roots: [root], userHome: home, detectResidue: false
        ).scan(options: ScanOptions()) { _ in }

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.category == .uninstaller })
        XCTAssertTrue(results.allSatisfy { $0.metadata["subcategory"] == "app" })
        let names = Set(results.compactMap { $0.metadata["display_name"] })
        XCTAssertEqual(names, ["Foo", "Bar"])
    }

    func testUninstallerScannerHandlesAppWithoutInfoPlist() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-uninst-broken-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let app = root.appendingPathComponent("Broken.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try Data(count: 256).write(to: app.appendingPathComponent("binary"))

        let home = try makeFakeUserHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let results = try await UninstallerScanner(
            roots: [root], userHome: home, detectResidue: false
        ).scan(options: ScanOptions()) { _ in }
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.metadata["bundle_id"], "")
        XCTAssertEqual(results.first?.metadata["display_name"], "Broken")
    }

    func testUninstallerScannerEmitsResidueGroupedByApp() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-uninst-res-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try makeFakeApp(name: "Acme", bundleID: "com.example.acme", in: root, fileSize: 2_048)

        let home = try makeFakeUserHome()
        defer { try? FileManager.default.removeItem(at: home) }

        // Lay down residue at two known locations.
        let cacheDir = home.appendingPathComponent("Library/Caches/com.example.acme")
        let prefsPlist = home.appendingPathComponent("Library/Preferences/com.example.acme.plist")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try Data(count: 8_192).write(to: cacheDir.appendingPathComponent("blob.cache"))
        try FileManager.default.createDirectory(
            at: prefsPlist.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(count: 1_024).write(to: prefsPlist)

        let results = try await UninstallerScanner(roots: [root], userHome: home, detectResidue: true)
            .scan(options: ScanOptions()) { _ in }

        let appItems = results.filter { $0.metadata["subcategory"] == "app" }
        let residueItems = results.filter { $0.metadata["subcategory"] == "residue" }
        XCTAssertEqual(appItems.count, 1)
        XCTAssertEqual(residueItems.count, 2)

        // App + its residue share a single groupID.
        let groupIDs = Set((appItems + residueItems).compactMap { $0.groupID })
        XCTAssertEqual(groupIDs.count, 1)

        // residue_kind metadata is set sensibly.
        let kinds = Set(residueItems.compactMap { $0.metadata["residue_kind"] })
        XCTAssertEqual(kinds, ["cache", "preferences"])
    }

    func testUninstallerScannerEmitsLeftoversForUninstalledApps() async throws {
        let appsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-uninst-lo-apps-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: appsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: appsDir) }
        // No installed apps at all.

        let home = try makeFakeUserHome()
        defer { try? FileManager.default.removeItem(at: home) }

        // Leftover that looks like a bundle id, larger than the min threshold.
        let leftoverCache = home.appendingPathComponent("Library/Caches/com.ghost.app")
        try FileManager.default.createDirectory(at: leftoverCache, withIntermediateDirectories: true)
        try Data(count: 1_000_000).write(to: leftoverCache.appendingPathComponent("big.cache"))

        // Below the min size — should be skipped.
        let smallLeftover = home.appendingPathComponent("Library/Caches/com.tiny.app")
        try FileManager.default.createDirectory(at: smallLeftover, withIntermediateDirectories: true)
        try Data(count: 100).write(to: smallLeftover.appendingPathComponent("noise.cache"))

        // Does NOT look like a bundle id — should be skipped.
        let nonBundleDir = home.appendingPathComponent("Library/Caches/NotABundle")
        try FileManager.default.createDirectory(at: nonBundleDir, withIntermediateDirectories: true)
        try Data(count: 1_000_000).write(to: nonBundleDir.appendingPathComponent("noise.cache"))

        let results = try await UninstallerScanner(
            roots: [appsDir],
            userHome: home,
            detectResidue: true,
            leftoverMinBytes: 500_000
        ).scan(options: ScanOptions()) { _ in }

        let leftovers = results.filter { $0.metadata["subcategory"] == "leftover" }
        XCTAssertEqual(leftovers.count, 1)
        XCTAssertEqual(leftovers.first?.metadata["bundle_id"], "com.ghost.app")
    }

    func testUninstallerScannerSkipsResidueForInstalledApps() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-uninst-skip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // Install Acme, then put a sibling Caches/com.example.acme — should
        // be emitted as RESIDUE not LEFTOVER, since Acme is still installed.
        _ = try makeFakeApp(name: "Acme", bundleID: "com.example.acme", in: root, fileSize: 1_024)

        let home = try makeFakeUserHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let cacheDir = home.appendingPathComponent("Library/Caches/com.example.acme")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try Data(count: 1_000_000).write(to: cacheDir.appendingPathComponent("blob.cache"))

        let results = try await UninstallerScanner(
            roots: [root], userHome: home, detectResidue: true, leftoverMinBytes: 1
        ).scan(options: ScanOptions()) { _ in }

        XCTAssertEqual(results.filter { $0.metadata["subcategory"] == "leftover" }.count, 0,
                       "Residue for an installed app must not be classified as leftover")
        XCTAssertEqual(results.filter { $0.metadata["subcategory"] == "residue" }.count, 1)
    }

    // ── MailScanner ──────────────────────────────────────────────────

    func testMailScannerFindsOnlyAttachments() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-mail-\(UUID().uuidString)", isDirectory: true)
        let attachmentsDir = root.appendingPathComponent("V10/acct/INBOX/Attachments/123")
        try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // One attachment under Attachments/, one envelope index outside it.
        let attachment = attachmentsDir.appendingPathComponent("invoice.pdf")
        let envelope = root.appendingPathComponent("V10/MailData/Envelope-Index")
        try FileManager.default.createDirectory(
            at: envelope.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(count: 4_096).write(to: attachment)
        try Data(count: 2_048).write(to: envelope)

        let results = try await MailScanner(roots: [root])
            .scan(options: ScanOptions()) { _ in }

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.path.lastPathComponent, "invoice.pdf")
        XCTAssertEqual(results.first?.category, .mailCache)
        XCTAssertEqual(results.first?.riskLevel, .caution)
        XCTAssertEqual(results.first?.metadata["subcategory"], "attachment")
    }

    // ── DeveloperScanner ─────────────────────────────────────────────

    func testDeveloperScannerTagsDerivedDataAndSimulatorCaches() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-dev-\(UUID().uuidString)", isDirectory: true)
        let derived = base.appendingPathComponent("DerivedData/MyAppHash")
        let simCache = base.appendingPathComponent("CoreSimulator/Caches/dyld")
        let xcodeCache = base.appendingPathComponent("com.apple.dt.Xcode/Downloads")
        for dir in [derived, simCache, xcodeCache] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: base) }

        try Data(count: 1_024).write(to: derived.appendingPathComponent("Build.o"))
        try Data(count: 1_024).write(to: simCache.appendingPathComponent("cache.bin"))
        try Data(count: 1_024).write(to: xcodeCache.appendingPathComponent("DocSet.dmg"))

        let results = try await DeveloperScanner(roots: [derived, simCache, xcodeCache])
            .scan(options: ScanOptions()) { _ in }

        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.category == .developerJunk })
        XCTAssertTrue(results.allSatisfy { $0.riskLevel == .safe })
        let subs = Set(results.compactMap { $0.metadata["subcategory"] })
        XCTAssertEqual(subs, ["deriveddata", "simulator-cache", "xcode-cache"])
    }

    // ── DuplicateScanner ─────────────────────────────────────────────

    /// Write `bytes` to `name` under `dir`, optionally backdating mtime.
    @discardableResult
    private func writeFile(_ name: String, in dir: URL, bytes: Data, modifiedDaysAgo: Int = 0) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try bytes.write(to: url)
        if modifiedDaysAgo > 0 {
            let date = Date().addingTimeInterval(-TimeInterval(modifiedDaysAgo) * 86_400)
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        return url
    }

    private func makeDuplicateFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-dup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func testDuplicateScannerFindsExactMatches() async throws {
        let root = try makeDuplicateFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let payload = Data(repeating: 0xAB, count: 8_192)
        try writeFile("original.bin", in: root, bytes: payload, modifiedDaysAgo: 30)
        try writeFile("copy.bin",     in: root, bytes: payload, modifiedDaysAgo: 5)

        let results = try await DuplicateScanner(roots: [root], minSize: 1_024)
            .scan(options: ScanOptions()) { _ in }

        XCTAssertEqual(results.count, 1, "Two identical files → exactly one duplicate emitted")
        XCTAssertEqual(results.first?.category, .duplicate)
        XCTAssertNotNil(results.first?.contentHash)
        XCTAssertEqual(results.first?.metadata["group_size"], "2")
        // Oldest is canonical → 'copy.bin' (the newer one) is the duplicate.
        XCTAssertEqual(results.first?.path.lastPathComponent, "copy.bin")
        XCTAssertTrue(results.first?.metadata["canonical_path"]?.hasSuffix("original.bin") ?? false)
    }

    func testDuplicateScannerEmitsAllButCanonicalInLargerGroup() async throws {
        let root = try makeDuplicateFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let payload = Data(repeating: 0x42, count: 8_192)
        try writeFile("a.bin", in: root, bytes: payload, modifiedDaysAgo: 30)
        try writeFile("b.bin", in: root, bytes: payload, modifiedDaysAgo: 20)
        try writeFile("c.bin", in: root, bytes: payload, modifiedDaysAgo: 10)

        let results = try await DuplicateScanner(roots: [root], minSize: 1_024)
            .scan(options: ScanOptions()) { _ in }

        XCTAssertEqual(results.count, 2, "Three identical files → two duplicates")
        // Same groupID for every duplicate in the set.
        let groupIDs = Set(results.compactMap { $0.groupID })
        XCTAssertEqual(groupIDs.count, 1)
        let names = Set(results.map { $0.path.lastPathComponent })
        XCTAssertEqual(names, ["b.bin", "c.bin"])
    }

    func testDuplicateScannerIgnoresSameSizeDifferentContent() async throws {
        let root = try makeDuplicateFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeFile("one.bin", in: root, bytes: Data(repeating: 0x01, count: 8_192))
        try writeFile("two.bin", in: root, bytes: Data(repeating: 0x02, count: 8_192))

        let results = try await DuplicateScanner(roots: [root], minSize: 1_024)
            .scan(options: ScanOptions()) { _ in }
        XCTAssertTrue(results.isEmpty, "Same size but different content is not a duplicate")
    }

    func testDuplicateScannerSkipsFilesBelowMinSize() async throws {
        let root = try makeDuplicateFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let tiny = Data(repeating: 0xFF, count: 100)
        try writeFile("a.tiny", in: root, bytes: tiny)
        try writeFile("b.tiny", in: root, bytes: tiny)

        let results = try await DuplicateScanner(roots: [root], minSize: 1_024)
            .scan(options: ScanOptions()) { _ in }
        XCTAssertTrue(results.isEmpty)
    }

    // ── DeletionEngine ───────────────────────────────────────────────

    /// Spins up an orchestrator pre-seeded with one or more ScanItems plus
    /// an isolated temp RecoveryStore. Returns everything the test needs.
    private func makeEngineFixture(
        items: [ScanItem]
    ) async -> (orchestrator: ScannerOrchestrator, store: RecoveryStore, base: URL, handle: ScanHandle) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-engine-\(UUID().uuidString)", isDirectory: true)
        let store = RecoveryStore(baseDirectory: base)
        let orchestrator = ScannerOrchestrator()
        let handle = ScanHandle()
        await orchestrator.seedForTesting(handle: handle, results: items)
        return (orchestrator, store, base, handle)
    }

    func testDeletionEngineMovesFileIntoArchive() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-engine-src-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let original = root.appendingPathComponent("big.bin")
        let payload = Data(count: 1_024)
        try payload.write(to: original)

        let item = ScanItem(
            path: original,
            category: .largeFile,
            bytes: Int64(payload.count),
            lastModified: Date(),
            lastAccessed: Date(),
            riskLevel: .caution
        )
        let fixture = await makeEngineFixture(items: [item])
        defer { try? FileManager.default.removeItem(at: fixture.base) }

        let report = try await DeletionEngine.shared.moveToRecoveryBin(
            itemIDs: [item.id],
            orchestrator: fixture.orchestrator,
            recoveryStore: fixture.store
        )

        XCTAssertEqual(report.movedCount, 1)
        XCTAssertEqual(report.bytesReclaimed, Int64(payload.count))
        XCTAssertTrue(report.skipped.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))

        let listed = try fixture.store.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.bytes, Int64(payload.count))
        XCTAssertTrue(FileManager.default.fileExists(atPath: listed.first?.archivedPath.path ?? ""))
    }

    func testDeletionEngineSkipsProtectedPaths() async throws {
        // /System is in ProtectedPaths — the engine must refuse it.
        let item = ScanItem(
            path: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            category: .systemJunk,
            bytes: 0,
            lastModified: Date(),
            lastAccessed: Date(),
            riskLevel: .protected
        )
        let fixture = await makeEngineFixture(items: [item])
        defer { try? FileManager.default.removeItem(at: fixture.base) }

        let report = try await DeletionEngine.shared.moveToRecoveryBin(
            itemIDs: [item.id],
            orchestrator: fixture.orchestrator,
            recoveryStore: fixture.store
        )

        XCTAssertEqual(report.movedCount, 0)
        XCTAssertEqual(report.skipped.count, 1)
        XCTAssertEqual(report.skipped.first?.reason, "Protected path")
    }

    func testDeletionEngineSkipsUnknownItemIDs() async throws {
        let fixture = await makeEngineFixture(items: [])
        defer { try? FileManager.default.removeItem(at: fixture.base) }

        let randomID = UUID()
        let report = try await DeletionEngine.shared.moveToRecoveryBin(
            itemIDs: [randomID],
            orchestrator: fixture.orchestrator,
            recoveryStore: fixture.store
        )

        XCTAssertEqual(report.movedCount, 0)
        XCTAssertEqual(report.skipped.count, 1)
        XCTAssertTrue(report.skipped.first?.reason.contains("not found") ?? false)
    }

    func testDeletionEngineRoundTripsThroughRestore() async throws {
        // Move a file in, then restore it — should land back at the original path.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pare-engine-rt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let original = root.appendingPathComponent("note.txt")
        try "hello".write(to: original, atomically: true, encoding: .utf8)

        let item = ScanItem(
            path: original,
            category: .downloads,
            bytes: 5,
            lastModified: Date(),
            lastAccessed: Date(),
            riskLevel: .safe
        )
        let fixture = await makeEngineFixture(items: [item])
        defer { try? FileManager.default.removeItem(at: fixture.base) }

        _ = try await DeletionEngine.shared.moveToRecoveryBin(
            itemIDs: [item.id],
            orchestrator: fixture.orchestrator,
            recoveryStore: fixture.store
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))

        let listed = try fixture.store.list()
        XCTAssertEqual(listed.count, 1)
        let restoreReport = try fixture.store.restore(itemIDs: [listed[0].id])
        XCTAssertEqual(restoreReport.restoredCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }

    func testPurgeRemovesExpiredItems() throws {
        let (store, base) = makeStore()
        defer { try? FileManager.default.removeItem(at: base) }

        let scanID = UUID()
        let archiveDir = try store.archiveDirectory(for: scanID)

        let staleArchive = archiveDir.appendingPathComponent("stale.txt")
        try "x".write(to: staleArchive, atomically: true, encoding: .utf8)
        let stale = RecoveryItem(
            originalPath: URL(fileURLWithPath: "/tmp/stale.txt"),
            archivedPath: staleArchive,
            bytes: 1,
            category: .systemJunk,
            removedAt: Date().addingTimeInterval(-60 * 24 * 60 * 60),
            purgesAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            scanID: scanID
        )
        try store.insert(stale)

        let freshArchive = archiveDir.appendingPathComponent("fresh.txt")
        try "y".write(to: freshArchive, atomically: true, encoding: .utf8)
        let fresh = RecoveryItem(
            originalPath: URL(fileURLWithPath: "/tmp/fresh.txt"),
            archivedPath: freshArchive,
            bytes: 1,
            category: .systemJunk,
            removedAt: Date(),
            purgesAt: Date().addingTimeInterval(30 * 24 * 60 * 60),
            scanID: scanID
        )
        try store.insert(fresh)

        let report = try store.purge(olderThan: Date())
        XCTAssertEqual(report.purgedCount, 1)
        XCTAssertEqual(report.bytesFreed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleArchive.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: freshArchive.path))
        XCTAssertEqual(try store.list().count, 1)
    }
}
