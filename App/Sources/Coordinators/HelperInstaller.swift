// App/Sources/Coordinators/HelperInstaller.swift
//
// Wraps SMAppService.daemon(plistName:) — the macOS 13+ API that installs
// and registers the privileged helper. Called once at app launch; safe to
// call repeatedly. In dev builds (where there is no enclosing .app bundle)
// registration is skipped with a clear log line instead of crashing.

import Foundation
import ServiceManagement
import PareKit

@MainActor
public final class HelperInstaller: ObservableObject {

    public static let shared = HelperInstaller()

    public enum InstallStatus: Equatable {
        case notInstalled
        case enabled
        case requiresApproval
        case unsupported(String)
    }

    @Published public private(set) var status: InstallStatus = .notInstalled

    private let log = PareLogger(.app, category: "helper-installer")
    private let service: SMAppService

    private init() {
        self.service = SMAppService.daemon(plistName: PareSigning.helperPlistName)
        refreshStatus()
    }

    /// Best-effort registration. Logs and updates `status` on failure rather
    /// than throwing — the UI shows a banner if the helper is missing.
    public func registerIfNeeded() {
        guard PareSigning.isConfigured else {
            log.warn("Skipping helper registration: PareSigning.expectedTeamID not set")
            status = .unsupported("Team ID not configured")
            return
        }

        refreshStatus()

        switch service.status {
        case .enabled:
            log.info("Helper already enabled")
            return
        case .requiresApproval:
            log.warn("Helper requires user approval in System Settings → Login Items")
            return
        case .notRegistered, .notFound:
            break
        @unknown default:
            break
        }

        do {
            try service.register()
            log.info("Helper registration submitted")
        } catch {
            log.error("Helper registration failed: \(error.localizedDescription)")
            status = .unsupported(error.localizedDescription)
            return
        }
        refreshStatus()
    }

    /// Unregister the helper (used by uninstall flows; not auto-called).
    public func unregister() {
        do {
            try service.unregister()
            log.info("Helper unregistered")
        } catch {
            log.error("Helper unregister failed: \(error.localizedDescription)")
        }
        refreshStatus()
    }

    /// Open System Settings → Login Items so the user can approve the helper.
    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func refreshStatus() {
        switch service.status {
        case .enabled:           status = .enabled
        case .requiresApproval:  status = .requiresApproval
        case .notRegistered:     status = .notInstalled
        case .notFound:          status = .notInstalled
        @unknown default:        status = .notInstalled
        }
    }
}
