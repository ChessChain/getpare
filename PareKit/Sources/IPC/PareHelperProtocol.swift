// PareKit/IPC/PareHelperProtocol.swift
//
// The single source of truth for the privileged helper's capabilities.
// Anything not on this interface is not callable from the sandboxed UI.

import Foundation

/// All custom Swift structs are serialized to Data (JSON) via XPCCoder
/// so they cross the NSXPCConnection boundary safely. Only ObjC-bridgeable
/// primitives (Data, String, Bool, Date) appear in method signatures.
@objc public protocol PareHelperProtocol {

    // ── Scanning ──────────────────────────────────────────────────────
    /// `optionsData`: JSON-encoded ScanOptions.
    /// Reply: JSON-encoded ScanHandle on success.
    func startScan(
        optionsData: Data,
        reply: @escaping (Data?, Error?) -> Void
    )

    /// `handleID`: UUID string of the ScanHandle.
    func cancelScan(
        handleID: String,
        reply: @escaping (Bool) -> Void
    )

    /// Reply: JSON-encoded ScanProgress (nil Data if handle not found).
    func scanProgress(
        handleID: String,
        reply: @escaping (Data?, Error?) -> Void
    )

    /// Reply: JSON-encoded [ScanItem].
    func scanResults(
        handleID: String,
        reply: @escaping (Data?, Error?) -> Void
    )

    // ── Cleanup (moves to Recovery Bin, never permanent) ──────────────
    /// `itemIDsData`: JSON-encoded [UUID].
    /// Reply: JSON-encoded CleanupReport.
    func moveToRecoveryBin(
        itemIDsData: Data,
        reply: @escaping (Data?, Error?) -> Void
    )

    // ── Recovery ──────────────────────────────────────────────────────
    /// Reply: JSON-encoded [RecoveryItem].
    func listRecoveryBin(
        reply: @escaping (Data?, Error?) -> Void
    )

    /// `itemIDsData`: JSON-encoded [UUID].
    /// Reply: JSON-encoded RestoreReport.
    func restore(
        itemIDsData: Data,
        reply: @escaping (Data?, Error?) -> Void
    )

    /// Reply: JSON-encoded PurgeReport.
    func purge(
        olderThan: Date,
        reply: @escaping (Data?, Error?) -> Void
    )

    // ── Permission status ────────────────────────────────────────────
    func fullDiskAccessGranted(
        reply: @escaping (Bool) -> Void
    )

    // ── Helper version (used by the app for compatibility checks) ────
    func version(
        reply: @escaping (String) -> Void
    )
}

public enum PareIPC {
    /// Mach service name. Must match the Helper's launchd plist and the
    /// SMAppService daemon registration in the App.
    public static let helperServiceName = "com.clearpath.pare.helper"

    /// Bumped whenever the protocol changes incompatibly. The App checks
    /// this on connection and prompts the user to reinstall the helper if
    /// the helper's reported version is older than the App's required one.
    public static let protocolVersion = 1
}
