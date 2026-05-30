// App/Sources/Views/Settings/SettingsView.swift

import SwiftUI
import AppKit

public struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var s = SettingsStore.shared
    @ObservedObject private var licence = LicenceManager.shared
    @ObservedObject private var bin = CleanedItemStore.shared
    @State private var activeTab = "general"
    @State private var keyInput = ""
    @State private var emailInput = ""
    @State private var activationMessage = ""
    @State private var showResetConfirm = false
    @State private var showEmptyBinConfirm = false
    @State private var showExcludedFolders = false

    public init() {}

    private let tabs: [(id: String, icon: String, label: String)] = [
        ("general",       "circle",          "General"),
        ("scanning",      "magnifyingglass", "Scanning"),
        ("notifications", "bell",            "Notifications"),
        ("privacy",       "lock.shield",     "Privacy"),
        ("licence",       "creditcard",      "Licence"),
        ("advanced",      "terminal",        "Advanced"),
    ]

    public var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Settings").italic().font(PareFont.display(30)).foregroundStyle(PareColor.ink)
                            Text("Preferences, scanning behaviour, and your Pare licence.").font(PareFont.body(13)).foregroundStyle(PareColor.ink3)
                        }
                        Spacer()
                        Button { coordinator.route = .dashboard } label: {
                            Text("Done").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                    .padding(.bottom, 20)
                    Divider().padding(.bottom, 22)

                    HStack(alignment: .top, spacing: 24) {
                        // Nav
                        VStack(spacing: 1) {
                            ForEach(tabs, id: \.id) { tab in
                                Button { activeTab = tab.id } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: tab.icon).font(.system(size: 13)).frame(width: 14).opacity(0.7)
                                        Text(tab.label).font(PareFont.body(13, weight: activeTab == tab.id ? .medium : .regular))
                                    }
                                    .foregroundStyle(activeTab == tab.id ? PareColor.bg : PareColor.ink2)
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(activeTab == tab.id ? PareColor.ink : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                                }.buttonStyle(.plain)
                            }
                        }
                        .frame(width: 200).padding(8)
                        .background(PareColor.surface).clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                        .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))

                        // Content
                        VStack(alignment: .leading, spacing: 0) {
                            switch activeTab {
                            case "general":       generalPanel
                            case "scanning":      scanningPanel
                            case "notifications": notificationsPanel
                            case "privacy":       privacyPanel
                            case "licence":       licencePanel
                            case "advanced":      advancedPanel
                            default:              generalPanel
                            }
                        }
                        .padding(28).frame(maxWidth: .infinity, alignment: .leading)
                        .background(PareColor.surface).clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                        .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 40).padding(.vertical, 32)
            }
            .background(PareColor.bg)

            if showResetConfirm { resetConfirmModal }
            if showEmptyBinConfirm { emptyBinModal }
        }
    }

    // MARK: - General

    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader("General", "Appearance and basic preferences.")
            row("Appearance", "Match macOS or pick a fixed theme.") {
                Picker("", selection: $s.appearance) {
                    Text("Match system").tag("Match system"); Text("Light").tag("Light"); Text("Dark").tag("Dark")
                }.labelsHidden().frame(width: 140)
            }
            row("Language", "v1.0 ships in English; locale packs land in v1.1.") {
                Text("English").font(PareFont.mono(12)).foregroundStyle(PareColor.ink2)
            }
            row("Menu bar item", "Show free space and quick actions in the menu bar.") {
                Toggle("", isOn: $s.menuBarEnabled).toggleStyle(.switch).tint(PareColor.forest)
            }
            rowLast("Launch at login", "Pare opens silently and idles until you summon it.") {
                Toggle("", isOn: $s.launchAtLogin).toggleStyle(.switch).tint(PareColor.forest)
            }
        }
    }

    // MARK: - Scanning

    private var scanningPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader("Scanning", "When and where Pare scans your Mac.")
            row("Scheduled scans", "Background scans keep results fresh. Pare never deletes on a schedule.") {
                Picker("", selection: $s.scheduledScans) {
                    Text("Off").tag("Off"); Text("Weekly").tag("Weekly"); Text("Daily").tag("Daily"); Text("Monthly").tag("Monthly")
                }.labelsHidden().frame(width: 120)
            }
            row("Large file threshold", "Default size at which files are surfaced as candidates.") {
                HStack(spacing: 12) {
                    Slider(value: $s.largeFileThreshold, in: 50...2000, step: 50).frame(width: 160).tint(PareColor.forest)
                    Text("> \(Int(s.largeFileThreshold)) MB").font(PareFont.mono(12)).foregroundStyle(PareColor.ink2).frame(width: 80, alignment: .trailing)
                }
            }
            row("Excluded folders", "Pare will never scan or list files inside these paths.") {
                actionBtn("Manage\u{2026}") { showExcludedFolders = true }
            }
            rowLast("Auto-empty Trash", "Move items in macOS Trash older than 30 days to Recovery Bin.") {
                Toggle("", isOn: $s.autoEmptyTrash).toggleStyle(.switch).tint(PareColor.forest)
            }
        }
        .sheet(isPresented: $showExcludedFolders) { excludedFoldersSheet }
    }

    // MARK: - Notifications

    private var notificationsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader("Notifications", "Pare only notifies you about things you\u{2019}d want to know about.")
            row("Low free space alert", "Notify when free space drops below this threshold.") {
                Picker("", selection: $s.lowSpaceAlert) {
                    Text("Off").tag("Off"); Text("Below 10%").tag("Below 10%"); Text("Below 15%").tag("Below 15%"); Text("Below 25%").tag("Below 25%")
                }.labelsHidden().frame(width: 130)
            }
            row("Scan completion", "Banner when a scheduled scan finishes while Pare is closed.") {
                Toggle("", isOn: $s.scanCompletionNotify).toggleStyle(.switch).tint(PareColor.forest)
            }
            rowLast("Weekly Recovery Bin digest", "Once a week: what\u{2019}s about to be auto-purged.") {
                Toggle("", isOn: $s.weeklyDigest).toggleStyle(.switch).tint(PareColor.forest)
            }
        }
    }

    // MARK: - Privacy

    @ObservedObject private var permissions = PermissionManager.shared
    @ObservedObject private var installer = HelperInstaller.shared

    private var privacyPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader("Privacy", "Nothing leaves your Mac without your explicit opt-in.")

            // Full Disk Access status
            HStack(spacing: 14) {
                Image(systemName: permissions.hasFullDiskAccess ? "checkmark.shield.fill" : "exclamationmark.shield")
                    .font(.system(size: 20))
                    .foregroundStyle(permissions.hasFullDiskAccess ? PareColor.forest : PareColor.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Disk Access").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                    Text(permissions.hasFullDiskAccess
                         ? "Granted \u{2014} Pare can scan all directories including Mail, Developer, and protected caches."
                         : "Not granted \u{2014} Pare can only scan user-accessible directories. Grant access for a complete scan.")
                        .font(PareFont.body(12)).foregroundStyle(PareColor.ink3).lineSpacing(2)
                }
                Spacer()
                if permissions.hasFullDiskAccess {
                    Text("GRANTED").font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.forest)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(PareColor.accentSoft).clipShape(Capsule())
                        .overlay(Capsule().stroke(PareColor.accentLine, lineWidth: 1))
                } else {
                    VStack(spacing: 8) {
                        Button {
                            permissions.openSystemSettings()
                        } label: {
                            Text("Open Settings").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white)
                                .padding(.horizontal, 16).padding(.vertical, 8).background(PareColor.forest).clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)

                        Button {
                            permissions.markAsGranted()
                        } label: {
                            Text("I\u{2019}ve already granted it")
                                .font(PareFont.body(11)).foregroundStyle(PareColor.ink4)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(permissions.hasFullDiskAccess ? PareColor.accentSoft : PareColor.warningSoft)
            .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(
                permissions.hasFullDiskAccess ? PareColor.accentLine : Color(red: 0.894, green: 0.784, blue: 0.588), lineWidth: 1))
            .padding(.bottom, 16)

            // Privileged helper status
            helperStatusBlock
                .padding(.bottom, 16)

            row("Anonymous telemetry", "Event counts only (no paths, filenames, or contents). Off by default.") {
                Toggle("", isOn: $s.telemetryEnabled).toggleStyle(.switch).tint(PareColor.forest)
            }
            row("Crash reports", "Send only stack traces if Pare crashes.") {
                Toggle("", isOn: $s.crashReportsEnabled).toggleStyle(.switch).tint(PareColor.forest)
            }
            row("Audit log", "Every helper operation is logged locally at ~/Library/Logs/Pare/audit.log.") {
                actionBtn("Show in Finder") {
                    let logDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Pare")
                    try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logDir.path)
                }
            }
            row("Privacy policy", "Plain-language. On-device only, no data leaves your Mac.") {
                actionBtn("View") {
                    if let url = URL(string: "https://getpare.lemonsqueezy.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            rowLast("Regulatory compliance", "Pare complies with NDPA 2023 and GDPR. On-device processing, opt-in telemetry.") {
                Text("NDPA \u{00B7} GDPR").font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.forest)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(PareColor.accentSoft).clipShape(Capsule())
                    .overlay(Capsule().stroke(PareColor.accentLine, lineWidth: 1))
            }
        }
    }

    /// Block in the Privacy panel showing the privileged helper's install state.
    @ViewBuilder
    private var helperStatusBlock: some View {
        let copy = helperCopy(for: installer.status)
        HStack(spacing: 14) {
            Image(systemName: copy.icon)
                .font(.system(size: 20))
                .foregroundStyle(copy.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Privileged helper")
                    .font(PareFont.body(13, weight: .medium))
                    .foregroundStyle(PareColor.ink)
                Text(copy.body)
                    .font(PareFont.body(12))
                    .foregroundStyle(PareColor.ink3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            switch installer.status {
            case .enabled:
                Text("INSTALLED")
                    .font(PareFont.mono(10, weight: .medium))
                    .foregroundStyle(PareColor.forest)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(PareColor.accentSoft).clipShape(Capsule())
                    .overlay(Capsule().stroke(PareColor.accentLine, lineWidth: 1))
            case .requiresApproval:
                Button {
                    installer.openLoginItemsSettings()
                } label: {
                    Text("Open Login Items")
                        .font(PareFont.body(13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(PareColor.forest)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            case .notInstalled:
                Button {
                    installer.registerIfNeeded()
                } label: {
                    Text("Install")
                        .font(PareFont.body(13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(PareColor.forest)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            case .unsupported:
                EmptyView()
            }
        }
        .padding(16)
        .background(helperBackground(for: installer.status))
        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
        .overlay(
            RoundedRectangle(cornerRadius: PareRadius.standard)
                .stroke(helperBorder(for: installer.status), lineWidth: 1)
        )
    }

    private func helperCopy(
        for status: HelperInstaller.InstallStatus
    ) -> (icon: String, tint: Color, body: String) {
        switch status {
        case .enabled:
            return ("checkmark.shield.fill", PareColor.forest,
                    "Installed — every scan and cleanup runs through the privileged helper with Full Disk Access.")
        case .requiresApproval:
            return ("exclamationmark.shield", PareColor.warning,
                    "Pending approval — open System Settings → Login Items and enable Pare to finish setup.")
        case .notInstalled:
            return ("xmark.shield", PareColor.warning,
                    "Not installed — Pare is running in limited mode and walks the filesystem directly. Some TCC-protected paths may be invisible.")
        case .unsupported(let reason):
            return ("info.circle", PareColor.ink3,
                    "Unavailable: \(reason)")
        }
    }

    private func helperBackground(for status: HelperInstaller.InstallStatus) -> Color {
        switch status {
        case .enabled:          return PareColor.accentSoft
        case .requiresApproval: return PareColor.warningSoft
        case .notInstalled:     return PareColor.warningSoft
        case .unsupported:      return PareColor.surface2
        }
    }

    private func helperBorder(for status: HelperInstaller.InstallStatus) -> Color {
        switch status {
        case .enabled:          return PareColor.accentLine
        case .requiresApproval: return Color(red: 0.894, green: 0.784, blue: 0.588)
        case .notInstalled:     return Color(red: 0.894, green: 0.784, blue: 0.588)
        case .unsupported:      return PareColor.line
        }
    }

    // MARK: - Licence

    private var licencePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader("Licence", "Your tier, usage, and licence key.")

            // Tier card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(licence.isPremium ? "Premium" : "Free").font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.ink)
                        Text("Tier").font(PareFont.display(22)).italic().foregroundStyle(PareColor.forest)
                    }
                    if licence.isPremium {
                        Text("Unlimited reclamation \u{00B7} all features unlocked").font(PareFont.body(12)).foregroundStyle(PareColor.forest)
                    } else {
                        Text("500 MB monthly reclamation cap").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(PareColor.line).frame(height: 6)
                            RoundedRectangle(cornerRadius: 3).fill(licence.isOverLimit ? PareColor.warning : PareColor.forest)
                                .frame(width: max(1, 220 * licence.usagePercent), height: 6)
                        }.frame(width: 220)
                        Text(licence.usageLabel + " used this month")
                            .font(PareFont.mono(11)).foregroundStyle(licence.isOverLimit ? PareColor.warning : PareColor.ink3)
                    }
                }
                Spacer()
                if !licence.isPremium {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Purchase a licence key at").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                        Text("getpare.lemonsqueezy.com").font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.forest)
                    }
                }
            }
            .padding(20).background(PareColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
            .padding(.bottom, 16)

            if !licence.isPremium {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Activate licence key").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                    Text("Enter the key from your purchase confirmation email.").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)

                    TextField("Email", text: $emailInput)
                        .textFieldStyle(.plain).font(PareFont.body(14))
                        .padding(11).background(PareColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))

                    TextField("PARE-XXXXX-XXXXX-XXXXX-XXXXX", text: $keyInput)
                        .textFieldStyle(.plain).font(PareFont.mono(14))
                        .padding(11).background(PareColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))

                    HStack {
                        Button {
                            let result = licence.activate(key: keyInput, email: emailInput)
                            switch result {
                            case .success(let tier): activationMessage = "\u{2713} Activated! You\u{2019}re now on \(tier.rawValue.capitalized)."
                            case .invalidKey:        activationMessage = "Invalid key. Check your email for the correct key."
                            case .alreadyActivated:  activationMessage = "This key is already active."
                            }
                        } label: {
                            Text("Activate").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white)
                                .padding(.horizontal, 20).padding(.vertical, 10).background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)

                        if !activationMessage.isEmpty {
                            Text(activationMessage).font(PareFont.body(12))
                                .foregroundStyle(activationMessage.hasPrefix("\u{2713}") ? PareColor.forest : PareColor.warning)
                        }
                    }
                }.padding(.bottom, 16)
            } else {
                row("Licence key", "Active and validated.") {
                    Text(licence.licenceKey).font(PareFont.mono(11)).foregroundStyle(PareColor.ink2)
                }
                row("Email", "Associated with this licence.") {
                    Text(licence.licenceEmail).font(PareFont.mono(11)).foregroundStyle(PareColor.ink2)
                }
                row("Deactivate", "Remove this licence from this Mac to use on another device.") {
                    dangerBtn("Deactivate") { licence.deactivate() }
                }
            }

            rowLast("Contact support", "support@pare.app \u{00B7} responses within 1 business day.") {
                actionBtn("Email Support") {
                    NSWorkspace.shared.open(URL(string: "mailto:support@pare.app")!)
                }
            }
        }
    }

    // MARK: - Advanced

    private var advancedPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader("Advanced", "For power users. Be careful in here.")
            row("Recovery Bin size cap", "If the bin exceeds this, Pare auto-purges the oldest items.") {
                HStack(spacing: 12) {
                    Slider(value: $s.binCapGB, in: 2...50, step: 1).frame(width: 160).tint(PareColor.forest)
                    Text("\(Int(s.binCapGB)) GB").font(PareFont.mono(12)).foregroundStyle(PareColor.ink2).frame(width: 60, alignment: .trailing)
                }
            }
            row("Default scan depth", "Standard covers all categories. Deep includes hashing for large files.") {
                Picker("", selection: $s.scanDepth) { Text("Standard").tag("Standard"); Text("Deep").tag("Deep") }.labelsHidden().frame(width: 120)
            }
            row("Update channel", "Beta builds arrive a week earlier. Opt in at your own risk.") {
                Picker("", selection: $s.updateChannel) { Text("Stable").tag("Stable"); Text("Beta").tag("Beta") }.labelsHidden().frame(width: 120)
            }
            row("Empty Recovery Bin now", "Permanently removes all \(bin.totalCount) items currently in the bin.") {
                dangerBtn("Empty Bin\u{2026}") { showEmptyBinConfirm = true }
            }
            rowLast("Reset all preferences", "Restores Pare to default settings. Recovery Bin and licence are preserved.") {
                dangerBtn("Reset\u{2026}") { showResetConfirm = true }
            }
        }
    }

    // MARK: - Modals

    private var resetConfirmModal: some View {
        confirmModal(
            title: "Reset all preferences?",
            message: "This restores every setting to its default value. Your Recovery Bin and licence key are preserved.",
            confirmLabel: "Reset",
            isDanger: true
        ) {
            s.resetAll()
            showResetConfirm = false
        } onCancel: {
            showResetConfirm = false
        }
    }

    private var emptyBinModal: some View {
        confirmModal(
            title: "Empty Recovery Bin?",
            message: "This permanently removes \(bin.totalCount) items (\(bin.totalSizeLabel)) from your Recovery Bin. This cannot be undone.",
            confirmLabel: "Empty Bin",
            isDanger: true
        ) {
            bin.removeAll()
            showEmptyBinConfirm = false
        } onCancel: {
            showEmptyBinConfirm = false
        }
    }

    private var excludedFoldersSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Excluded Folders").font(PareFont.display(20)).foregroundStyle(PareColor.ink)
            Text("Pare will never scan or list files inside these paths.").font(PareFont.body(13)).foregroundStyle(PareColor.ink3)

            if s.excludedFolders.isEmpty {
                Text("No excluded folders. Click + to add one.")
                    .font(PareFont.mono(11)).foregroundStyle(PareColor.ink4)
                    .padding(.vertical, 20).frame(maxWidth: .infinity)
            } else {
                ForEach(s.excludedFolders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "folder").foregroundStyle(PareColor.ink3)
                        Text(folder).font(PareFont.mono(12)).foregroundStyle(PareColor.ink2).lineLimit(1)
                        Spacer()
                        Button {
                            s.excludedFolders.removeAll { $0 == folder }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .medium)).foregroundStyle(PareColor.ink4)
                        }.buttonStyle(.plain)
                    }
                    .padding(10).background(PareColor.surface2).clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack {
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = true
                    if panel.runModal() == .OK {
                        for url in panel.urls {
                            let path = url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
                            if !s.excludedFolders.contains(path) {
                                s.excludedFolders.append(path)
                            }
                        }
                    }
                } label: {
                    Text("+ Add Folder").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                }.buttonStyle(.plain)
                Spacer()
                Button { showExcludedFolders = false } label: {
                    Text("Done").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 8).background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
        }
        .padding(24).frame(width: 480).background(PareColor.bg)
    }

    // MARK: - Helpers

    private func panelHeader(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(PareFont.display(20)).foregroundStyle(PareColor.ink)
            Text(sub).font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
        }.padding(.bottom, 24)
    }

    private func row(_ label: String, _ hint: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                Text(hint).font(PareFont.body(12)).foregroundStyle(PareColor.ink3).lineSpacing(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func rowLast(_ label: String, _ hint: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                Text(hint).font(PareFont.body(12)).foregroundStyle(PareColor.ink3).lineSpacing(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
            control()
        }.padding(.vertical, 14)
    }

    private func actionBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func dangerBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.danger)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.831, green: 0.690, blue: 0.690), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func confirmModal(title: String, message: String, confirmLabel: String, isDanger: Bool, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { onCancel() }
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(PareFont.display(22)).foregroundStyle(PareColor.ink)
                Text(message).font(PareFont.body(13)).foregroundStyle(PareColor.ink2).lineSpacing(3)
                HStack {
                    Spacer()
                    Button { onCancel() } label: {
                        Text("Cancel").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }.buttonStyle(.plain)
                    Button { onConfirm() } label: {
                        Text(confirmLabel).font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(.white).padding(.horizontal, 20).padding(.vertical, 10)
                            .background(isDanger ? PareColor.danger : PareColor.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            .padding(32).frame(maxWidth: 420).background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 40, y: 12)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))
        }
    }
}
