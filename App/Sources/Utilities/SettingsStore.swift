// App/Sources/Utilities/SettingsStore.swift
//
// Persistent settings backed by UserDefaults.
// All Settings panels read/write from this singleton.

import Foundation
import Combine
import SwiftUI
import AppKit
import ServiceManagement

public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    // MARK: - General

    @Published public var appearance: String {
        didSet {
            defaults.set(appearance, forKey: "pare.settings.appearance")
            applyAppearance()
        }
    }
    @Published public var menuBarEnabled: Bool {
        didSet { defaults.set(menuBarEnabled, forKey: "pare.settings.menuBar") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "pare.settings.launchAtLogin")
            updateLoginItem()
        }
    }

    // MARK: - Scanning

    @Published var scheduledScans: String {
        didSet { defaults.set(scheduledScans, forKey: "pare.settings.scheduledScans") }
    }
    @Published var largeFileThreshold: Double {
        didSet { defaults.set(largeFileThreshold, forKey: "pare.settings.threshold") }
    }
    @Published var autoEmptyTrash: Bool {
        didSet { defaults.set(autoEmptyTrash, forKey: "pare.settings.autoEmptyTrash") }
    }
    @Published var excludedFolders: [String] {
        didSet { defaults.set(excludedFolders, forKey: "pare.settings.excludedFolders") }
    }

    // MARK: - Notifications

    @Published var lowSpaceAlert: String {
        didSet { defaults.set(lowSpaceAlert, forKey: "pare.settings.lowSpaceAlert") }
    }
    @Published var scanCompletionNotify: Bool {
        didSet { defaults.set(scanCompletionNotify, forKey: "pare.settings.scanCompletion") }
    }
    @Published var weeklyDigest: Bool {
        didSet { defaults.set(weeklyDigest, forKey: "pare.settings.weeklyDigest") }
    }

    // MARK: - Privacy

    @Published var telemetryEnabled: Bool {
        didSet { defaults.set(telemetryEnabled, forKey: "pare.settings.telemetry") }
    }
    @Published var crashReportsEnabled: Bool {
        didSet { defaults.set(crashReportsEnabled, forKey: "pare.settings.crashReports") }
    }

    // MARK: - Advanced

    @Published var scanDepth: String {
        didSet { defaults.set(scanDepth, forKey: "pare.settings.scanDepth") }
    }
    @Published var updateChannel: String {
        didSet { defaults.set(updateChannel, forKey: "pare.settings.updateChannel") }
    }
    @Published var binCapGB: Double {
        didSet { defaults.set(binCapGB, forKey: "pare.settings.binCapGB") }
    }

    // MARK: - Init

    private init() {
        appearance = defaults.string(forKey: "pare.settings.appearance") ?? "Match system"
        menuBarEnabled = defaults.object(forKey: "pare.settings.menuBar") as? Bool ?? true
        launchAtLogin = defaults.object(forKey: "pare.settings.launchAtLogin") as? Bool ?? false
        scheduledScans = defaults.string(forKey: "pare.settings.scheduledScans") ?? "Weekly"
        largeFileThreshold = defaults.object(forKey: "pare.settings.threshold") as? Double ?? 100
        autoEmptyTrash = defaults.object(forKey: "pare.settings.autoEmptyTrash") as? Bool ?? true
        excludedFolders = defaults.stringArray(forKey: "pare.settings.excludedFolders") ?? []
        lowSpaceAlert = defaults.string(forKey: "pare.settings.lowSpaceAlert") ?? "Below 10%"
        scanCompletionNotify = defaults.object(forKey: "pare.settings.scanCompletion") as? Bool ?? true
        weeklyDigest = defaults.object(forKey: "pare.settings.weeklyDigest") as? Bool ?? true
        telemetryEnabled = defaults.object(forKey: "pare.settings.telemetry") as? Bool ?? false
        crashReportsEnabled = defaults.object(forKey: "pare.settings.crashReports") as? Bool ?? false
        scanDepth = defaults.string(forKey: "pare.settings.scanDepth") ?? "Standard"
        updateChannel = defaults.string(forKey: "pare.settings.updateChannel") ?? "Stable"
        binCapGB = defaults.object(forKey: "pare.settings.binCapGB") as? Double ?? 10

        // Apply saved appearance on launch
        applyAppearance()
    }

    // MARK: - Computed

    public var colorScheme: ColorScheme? {
        switch appearance {
        case "Light": return .light
        case "Dark":  return .dark
        default:      return nil
        }
    }

    // MARK: - Apply Appearance

    public func applyAppearance() {
        DispatchQueue.main.async {
            switch self.appearance {
            case "Light":
                NSApp.appearance = NSAppearance(named: .aqua)
            case "Dark":
                NSApp.appearance = NSAppearance(named: .darkAqua)
            default:
                NSApp.appearance = nil // follow system
            }
        }
    }

    // MARK: - Actions

    func resetAll() {
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("pare.settings.") }
        for key in keys { defaults.removeObject(forKey: key) }
        // Reload defaults
        appearance = "Match system"
        menuBarEnabled = true
        launchAtLogin = false
        scheduledScans = "Weekly"
        largeFileThreshold = 100
        autoEmptyTrash = true
        excludedFolders = []
        lowSpaceAlert = "Below 10%"
        scanCompletionNotify = true
        weeklyDigest = true
        telemetryEnabled = false
        crashReportsEnabled = false
        scanDepth = "Standard"
        updateChannel = "Stable"
        binCapGB = 10
    }

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Silently fail — requires proper app bundle
            }
        }
    }
}
