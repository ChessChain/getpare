// App/Sources/PareApp.swift
//
// Shared views used by the entry point. The @main App struct lives in
// App/EntryPoint/PareApp.swift so this library target stays testable.

import SwiftUI
import PareKit

/// Top-level view: shows onboarding flow on first launch,
/// then the main sidebar + detail layout.
public struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    public init() {}

    public var body: some View {
        Group {
            if coordinator.onboardingStep != .complete {
                onboardingView
            } else {
                mainView
            }
        }
    }

    @ViewBuilder
    private var onboardingView: some View {
        switch coordinator.onboardingStep {
        case .splash:
            SplashView()
        case .welcome:
            WelcomeView { coordinator.advanceOnboarding() }
        case .choosePlan:
            ChoosePlanView()
        case .complete:
            EmptyView()
        }
    }

    private var mainView: some View {
        HStack(spacing: 0) {
            Sidebar()
            Divider()
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch coordinator.route {
        case .dashboard:     DashboardView()
        case .scan:          DashboardView() // Smart Scan runs inline on dashboard
        case .spaceLens:     SpaceLensView()
        case .systemJunk:    CategoryDetailView(category: .systemJunk)
        case .duplicates:    CategoryDetailView(category: .duplicates)
        case .largeFiles:    CategoryDetailView(category: .largeFiles)
        case .downloads:     CategoryDetailView(category: .downloads)
        case .photos:        PhotosView()
        case .uninstaller:   UninstallerView()
        case .mailCleanup:   CategoryDetailView(category: .mailCleanup)
        case .developerJunk: CategoryDetailView(category: .developerJunk)
        case .startupItems:  StartupItemsView()
        case .browserCleanup: BrowserCleanupView()
        case .iCloudStorage: ICloudStorageView()
        case .recovery:      RecoveryView()
        case .insights:      InsightsView()
        case .profile:       ProfileView()
        case .subscription:  SubscriptionView()
        case .settings:      SettingsView()
        case .help:          HelpView()
        }
    }

    /// Always show the scan view — it works with whatever access is available.
    /// A banner at the top shows if FDA is missing (non-blocking).
    private var scanOrDenied: some View {
        ScanView()
    }
}

/// Menu-bar dropdown matching the v0.6 prototype.
public struct MenuBarContent: View {
    @StateObject private var vm = MenuBarViewModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(vm.freeLabel)
                        .font(PareFont.display(22, weight: .medium))
                        .foregroundStyle(PareColor.ink)
                    Text("FREE")
                        .font(PareFont.mono(10))
                        .foregroundStyle(PareColor.ink3)
                }
                Text(vm.reclaimLabel)
                    .font(PareFont.mono(12))
                    .foregroundStyle(PareColor.forest)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)

            Divider().padding(.horizontal, 4)

            // Primary actions
            MenuBarRow(icon: "magnifyingglass", label: "Run Smart Scan", meta: "\u{2318}R")
            MenuBarRow(icon: "square.grid.2x2", label: "Open Pare", meta: "\u{2318}O")
            MenuBarRow(icon: "trash.slash", label: "View Recovery Bin", meta: "14 items")

            Divider().padding(.horizontal, 4)

            // Settings
            MenuBarRow(icon: "bell.slash", label: "Notifications paused for 1 hr", meta: "change")
            MenuBarRow(icon: "gearshape", label: "Pare Settings\u{2026}", meta: "\u{2318},")

            Divider().padding(.horizontal, 4)

            // Quit
            MenuBarRow(icon: "power", label: "Quit Pare", meta: "\u{2318}Q", isDanger: true) {
                NSApplication.shared.terminate(nil)
            }

            Spacer().frame(height: 6)
        }
        .frame(width: 300)
    }
}

// MARK: - Menu Bar Row

private struct MenuBarRow: View {
    let icon: String
    let label: String
    let meta: String
    var isDanger: Bool = false
    var action: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 14)
                    .opacity(0.7)
                Text(label)
                    .font(PareFont.body(13))
                Spacer()
                Text(meta)
                    .font(PareFont.mono(11))
                    .foregroundStyle(PareColor.ink3)
            }
            .foregroundStyle(isHovered && isDanger ? PareColor.danger : PareColor.ink2)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: PareRadius.small)
                    .fill(isHovered ? PareColor.ink.opacity(0.05) : Color.clear)
            )
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Menu Bar ViewModel

private final class MenuBarViewModel: ObservableObject {
    @Published var freeLabel: String = "..."
    @Published var reclaimLabel: String = ""

    init() {
        // Volume stats — instant
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let free = (attrs[.systemFreeSize] as? Int64) ?? 0
            freeLabel = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
        }
        reclaimLabel = "scanning..."

        // Directory sizes in background — match dashboard calculation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let home = FileManager.default.homeDirectoryForCurrentUser
            let caches = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Caches"))
            let logs = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Logs"))
            let downloads = SystemStorageProvider.directorySize(home.appendingPathComponent("Downloads"))
            let developer = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Developer"))
            let mail = SystemStorageProvider.directorySize(home.appendingPathComponent("Library/Mail"))
            let total = caches + logs + downloads + developer + mail
            DispatchQueue.main.async {
                self?.reclaimLabel = "\(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)) reclaimable"
            }
        }
    }
}
