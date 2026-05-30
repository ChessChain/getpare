// Helper/Sources/XPCService.swift
//
// NSXPCListenerDelegate that vends a HelperImplementation per connection.
// All scanning/cleanup work is delegated to the orchestrator and engines.

import Foundation
import Security
import PareKit

public final class XPCService: NSObject, NSXPCListenerDelegate {

    private let log = PareLogger(.ipc, category: "service")
    private let orchestrator = ScannerOrchestrator()
    private let recoveryStore = RecoveryStore()

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection conn: NSXPCConnection) -> Bool {
        guard PareSigning.isConfigured else {
            log.error(
                "Rejecting XPC connection pid=\(conn.processIdentifier): "
                + "PareSigning.expectedTeamID is still the placeholder. "
                + "Set it in PareKit/IPC/PareSigning.swift before running a signed build."
            )
            return false
        }
        guard Self.validateClientSignature(conn) else {
            log.error("Rejected XPC connection pid=\(conn.processIdentifier): code signature validation failed")
            return false
        }
        log.info("Accepted XPC connection pid=\(conn.processIdentifier)")
        conn.exportedInterface = NSXPCInterface(with: PareHelperProtocol.self)
        conn.exportedObject = HelperImplementation(
            orchestrator: orchestrator,
            recoveryStore: recoveryStore
        )
        conn.resume()
        return true
    }

    /// Verifies the connecting process was signed by the team in `PareSigning`.
    private static func validateClientSignature(_ conn: NSXPCConnection) -> Bool {
        var code: SecCode?
        let pid = conn.processIdentifier

        let attrs = [kSecGuestAttributePid: pid] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &code) == errSecSuccess,
              let clientCode = code else {
            return false
        }

        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
                PareSigning.codeSigningRequirement as CFString, [], &requirement
              ) == errSecSuccess,
              let req = requirement else {
            return false
        }

        return SecCodeCheckValidity(clientCode, [], req) == errSecSuccess
    }
}

/// Concrete implementation of the PareHelperProtocol. Methods are thin
/// adapters from the XPC interface to the orchestrator and recovery store.
/// All custom types are JSON-encoded to Data via XPCCoder.
final class HelperImplementation: NSObject, PareHelperProtocol {

    private let orchestrator: ScannerOrchestrator
    private let recoveryStore: RecoveryStore
    private let log = PareLogger(.helper, category: "implementation")

    init(orchestrator: ScannerOrchestrator, recoveryStore: RecoveryStore) {
        self.orchestrator = orchestrator
        self.recoveryStore = recoveryStore
    }

    // MARK: Scanning

    func startScan(optionsData: Data, reply: @escaping (Data?, Error?) -> Void) {
        Task {
            do {
                let options = try XPCCoder.decode(ScanOptions.self, from: optionsData)
                let handle = try await orchestrator.startScan(options: options)
                reply(try XPCCoder.encode(handle), nil)
            } catch {
                log.error("startScan failed: \(error.localizedDescription)")
                reply(nil, error)
            }
        }
    }

    func cancelScan(handleID: String, reply: @escaping (Bool) -> Void) {
        Task {
            guard let uuid = UUID(uuidString: handleID) else {
                reply(false)
                return
            }
            let cancelled = await orchestrator.cancel(handle: ScanHandle(id: uuid))
            reply(cancelled)
        }
    }

    func scanProgress(handleID: String, reply: @escaping (Data?, Error?) -> Void) {
        Task {
            guard let uuid = UUID(uuidString: handleID) else {
                reply(nil, nil)
                return
            }
            let progress = await orchestrator.progress(for: ScanHandle(id: uuid))
            do {
                reply(try progress.map { try XPCCoder.encode($0) }, nil)
            } catch {
                reply(nil, error)
            }
        }
    }

    func scanResults(handleID: String, reply: @escaping (Data?, Error?) -> Void) {
        Task {
            guard let uuid = UUID(uuidString: handleID) else {
                reply(nil, nil)
                return
            }
            let results = await orchestrator.results(for: ScanHandle(id: uuid))
            do {
                reply(try XPCCoder.encode(results), nil)
            } catch {
                reply(nil, error)
            }
        }
    }

    // MARK: Cleanup

    func moveToRecoveryBin(itemIDsData: Data, reply: @escaping (Data?, Error?) -> Void) {
        Task {
            do {
                let itemIDs = try XPCCoder.decode([UUID].self, from: itemIDsData)
                let report = try await DeletionEngine.shared.moveToRecoveryBin(
                    itemIDs: itemIDs,
                    orchestrator: orchestrator,
                    recoveryStore: recoveryStore
                )
                reply(try XPCCoder.encode(report), nil)
            } catch {
                log.error("moveToRecoveryBin failed: \(error.localizedDescription)")
                let fallback = CleanupReport(movedCount: 0, bytesReclaimed: 0, skipped: [], scanID: UUID())
                reply(try? XPCCoder.encode(fallback), error)
            }
        }
    }

    // MARK: Recovery

    func listRecoveryBin(reply: @escaping (Data?, Error?) -> Void) {
        do {
            let items = try recoveryStore.list()
            reply(try XPCCoder.encode(items), nil)
        } catch {
            reply(nil, error)
        }
    }

    func restore(itemIDsData: Data, reply: @escaping (Data?, Error?) -> Void) {
        do {
            let itemIDs = try XPCCoder.decode([UUID].self, from: itemIDsData)
            let report = try recoveryStore.restore(itemIDs: itemIDs)
            reply(try XPCCoder.encode(report), nil)
        } catch {
            reply(nil, error)
        }
    }

    func purge(olderThan: Date, reply: @escaping (Data?, Error?) -> Void) {
        do {
            let report = try recoveryStore.purge(olderThan: olderThan)
            reply(try XPCCoder.encode(report), nil)
        } catch {
            reply(nil, error)
        }
    }

    // MARK: Permissions / version

    func fullDiskAccessGranted(reply: @escaping (Bool) -> Void) {
        let probe = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db")
        reply(FileManager.default.isReadableFile(atPath: probe.path))
    }

    func version(reply: @escaping (String) -> Void) {
        reply("1.0.0-dev")
    }
}
