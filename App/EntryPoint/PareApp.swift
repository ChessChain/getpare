// App/EntryPoint/PareApp.swift
//
// Thin entry point. All views and coordinators live in AppLib
// so they can be @testable-imported by AppTests.

import SwiftUI
import AppKit
import PareKit
import AppLib

@main
struct PareApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        SettingsStore.shared.applyAppearance()
        // Start background services
        _ = NotificationService.shared
        _ = ScheduledScanService.shared
        _ = DiskHealthMonitor.shared
    }

    var body: some Scene {
        WindowGroup("Pare") {
            RootView()
                .environmentObject(coordinator)
                .frame(minWidth: 1100, minHeight: 680)
                .preferredColorScheme(SettingsStore.shared.colorScheme)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .onReceive(SettingsStore.shared.$appearance) { _ in
                    SettingsStore.shared.applyAppearance()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandMenu("Pare") {
                Button("Run Smart Scan") { coordinator.startScan() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Show Insights") { coordinator.show(.insights) }
                    .keyboardShortcut("i", modifiers: .command)
                Divider()
                Button("Dashboard") { coordinator.show(.dashboard) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Smart Scan") { coordinator.show(.scan) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Recovery Bin") { coordinator.show(.recovery) }
                    .keyboardShortcut("3", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(coordinator)
        }

        MenuBarExtra("Pare", systemImage: "internaldrive", isInserted: .constant(SettingsStore.shared.menuBarEnabled)) {
            MenuBarContent()
                .environmentObject(coordinator)
        }
    }
}
