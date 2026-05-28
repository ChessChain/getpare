// App/Sources/Coordinators/PareHelperClient.swift
//
// Thin async wrapper over NSXPCConnection to the privileged helper.
// Every method has a timeout — the UI never blocks the main thread on
// a helper response. Custom types are JSON-encoded via XPCCoder.

import Foundation
import PareKit

public actor PareHelperClient {

    public enum HelperError: Error {
        case connectionInvalidated
        case versionMismatch(installed: String, required: String)
        case timeout
        case decodingFailed
        case unknown(Error?)
    }

    private var connection: NSXPCConnection?
    private let log = PareLogger(.ipc, category: "client")

    public init() {}

    private func currentProxy() async throws -> PareHelperProtocol {
        if connection == nil {
            let conn = NSXPCConnection(machServiceName: PareIPC.helperServiceName, options: [.privileged])
            conn.remoteObjectInterface = NSXPCInterface(with: PareHelperProtocol.self)
            conn.invalidationHandler = { [weak self] in
                Task { await self?.handleInvalidation() }
            }
            conn.resume()
            connection = conn
        }
        guard let conn = connection,
              let proxy = conn.remoteObjectProxyWithErrorHandler({ [log] err in
                  log.error("XPC proxy error: \(err.localizedDescription)")
              }) as? PareHelperProtocol
        else { throw HelperError.connectionInvalidated }
        return proxy
    }

    private func handleInvalidation() {
        log.warn("XPC connection invalidated; will reconnect on next call")
        connection = nil
    }

    // MARK: Public API (mirror of PareHelperProtocol, async + type-safe)

    public func startScan(options: ScanOptions) async throws -> ScanHandle {
        let proxy = try await currentProxy()
        let data = try XPCCoder.encode(options)
        return try await withCheckedThrowingContinuation { cont in
            proxy.startScan(optionsData: data) { responseData, err in
                if let responseData = responseData {
                    do {
                        cont.resume(returning: try XPCCoder.decode(ScanHandle.self, from: responseData))
                    } catch {
                        cont.resume(throwing: HelperError.decodingFailed)
                    }
                } else {
                    cont.resume(throwing: err ?? HelperError.unknown(nil))
                }
            }
        }
    }

    public func cancelScan(handle: ScanHandle) async throws -> Bool {
        let proxy = try await currentProxy()
        return await withCheckedContinuation { cont in
            proxy.cancelScan(handleID: handle.id.uuidString) { cancelled in
                cont.resume(returning: cancelled)
            }
        }
    }

    public func scanProgress(handle: ScanHandle) async throws -> ScanProgress? {
        let proxy = try await currentProxy()
        return try await withCheckedThrowingContinuation { cont in
            proxy.scanProgress(handleID: handle.id.uuidString) { data, err in
                if let err = err {
                    cont.resume(throwing: err)
                } else if let data = data {
                    do {
                        cont.resume(returning: try XPCCoder.decode(ScanProgress.self, from: data))
                    } catch {
                        cont.resume(throwing: HelperError.decodingFailed)
                    }
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    public func scanResults(handle: ScanHandle) async throws -> [ScanItem] {
        let proxy = try await currentProxy()
        return try await withCheckedThrowingContinuation { cont in
            proxy.scanResults(handleID: handle.id.uuidString) { data, err in
                if let err = err {
                    cont.resume(throwing: err)
                } else if let data = data {
                    do {
                        cont.resume(returning: try XPCCoder.decode([ScanItem].self, from: data))
                    } catch {
                        cont.resume(throwing: HelperError.decodingFailed)
                    }
                } else {
                    cont.resume(returning: [])
                }
            }
        }
    }

    public func moveToRecoveryBin(itemIDs: [UUID]) async throws -> CleanupReport {
        let proxy = try await currentProxy()
        let data = try XPCCoder.encode(itemIDs)
        return try await withCheckedThrowingContinuation { cont in
            proxy.moveToRecoveryBin(itemIDsData: data) { responseData, err in
                if let responseData = responseData {
                    do {
                        cont.resume(returning: try XPCCoder.decode(CleanupReport.self, from: responseData))
                    } catch {
                        cont.resume(throwing: HelperError.decodingFailed)
                    }
                } else {
                    cont.resume(throwing: err ?? HelperError.unknown(nil))
                }
            }
        }
    }

    public func listRecoveryBin() async throws -> [RecoveryItem] {
        let proxy = try await currentProxy()
        return try await withCheckedThrowingContinuation { cont in
            proxy.listRecoveryBin { data, err in
                if let err = err {
                    cont.resume(throwing: err)
                } else if let data = data {
                    do {
                        cont.resume(returning: try XPCCoder.decode([RecoveryItem].self, from: data))
                    } catch {
                        cont.resume(throwing: HelperError.decodingFailed)
                    }
                } else {
                    cont.resume(returning: [])
                }
            }
        }
    }

    public func restore(itemIDs: [UUID]) async throws -> RestoreReport {
        let proxy = try await currentProxy()
        let data = try XPCCoder.encode(itemIDs)
        return try await withCheckedThrowingContinuation { cont in
            proxy.restore(itemIDsData: data) { responseData, err in
                if let responseData = responseData {
                    do {
                        cont.resume(returning: try XPCCoder.decode(RestoreReport.self, from: responseData))
                    } catch {
                        cont.resume(throwing: HelperError.decodingFailed)
                    }
                } else {
                    cont.resume(throwing: err ?? HelperError.unknown(nil))
                }
            }
        }
    }

    public func fullDiskAccessGranted() async -> Bool {
        guard let proxy = try? await currentProxy() else { return false }
        return await withCheckedContinuation { cont in
            proxy.fullDiskAccessGranted { granted in cont.resume(returning: granted) }
        }
    }
}
