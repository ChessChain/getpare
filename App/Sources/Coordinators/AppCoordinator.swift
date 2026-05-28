// App/Sources/Coordinators/AppCoordinator.swift
//
// Owns the high-level navigation state, onboarding flow, permission
// management, and the long-lived helper client.

import SwiftUI
import PareKit

@MainActor
public final class AppCoordinator: ObservableObject {

    // MARK: - Onboarding

    public enum OnboardingStep: Equatable {
        case splash
        case welcome
        case choosePlan
        case complete
    }

    @Published public var onboardingStep: OnboardingStep = .complete

    /// True if onboarding has been completed (persisted in UserDefaults)
    public var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "pare.onboarding.complete") }
        set { UserDefaults.standard.set(newValue, forKey: "pare.onboarding.complete") }
    }

    // MARK: - Routing

    public enum Route: Hashable {
        case dashboard
        case scan
        case spaceLens
        case systemJunk
        case duplicates
        case largeFiles
        case downloads
        case photos
        case uninstaller
        case mailCleanup
        case developerJunk
        case startupItems
        case browserCleanup
        case iCloudStorage
        case recovery
        case insights
        case profile
        case subscription
        case settings
        case help
    }

    public enum ThemePreference: String, CaseIterable, Identifiable {
        case auto, light, dark
        public var id: String { rawValue }
    }

    @Published public var route: Route = .dashboard
    @Published public var themePreference: ThemePreference = .auto

    // MARK: - Permissions

    public let permissionManager = PermissionManager.shared

    public var colorScheme: ColorScheme? {
        switch themePreference {
        case .auto:  return nil
        case .light: return .light
        case .dark:  return .dark
        }
    }

    public init() {
        if !hasCompletedOnboarding {
            // CleanMyMac style: skip auth, start with splash → welcome → plan → use
            onboardingStep = .splash
        }
        permissionManager.hasFullDiskAccess = PermissionManager.checkFDA()
    }

    // MARK: - Navigation

    public func show(_ r: Route) {
        route = r
    }

    /// Triggers a full Smart Scan — refreshes all dashboard data in-place
    public func startScan() {
        // Post notification that all ViewModels listen for
        NotificationCenter.default.post(name: .init("PareSmartScanRequested"), object: nil)
    }

    // MARK: - Onboarding Flow

    public func advanceOnboarding() {
        switch onboardingStep {
        case .splash:     onboardingStep = .welcome
        case .welcome:    onboardingStep = .choosePlan
        case .choosePlan: completeOnboarding()
        case .complete:   break
        }
    }

    public func completeOnboarding() {
        hasCompletedOnboarding = true
        onboardingStep = .complete
        route = .dashboard
    }

    public func skipToLimitedMode() {
        hasCompletedOnboarding = true
        onboardingStep = .complete
        route = .dashboard
    }
}
