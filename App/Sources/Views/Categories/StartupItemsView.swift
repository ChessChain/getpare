// App/Sources/Views/Categories/StartupItemsView.swift

import SwiftUI

struct StartupItemsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = StartupItemsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Startup Items").italic().font(PareFont.display(30)).foregroundStyle(PareColor.ink)
                        Text("Apps and services that launch automatically when you log in. Disabling them speeds up boot and reduces background load.")
                            .font(PareFont.body(13)).foregroundStyle(PareColor.ink3)
                    }
                    Spacer()
                    Button { coordinator.route = .dashboard } label: {
                        Text("Back").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                .padding(.bottom, 20)
                Divider().padding(.bottom, 22)

                if vm.isLoading {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Scanning startup items...").font(PareFont.mono(11)).foregroundStyle(PareColor.ink4)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    // Summary
                    HStack(spacing: 12) {
                        statCard("Login Items", "\(vm.loginItems)")
                        statCard("LaunchAgents", "\(vm.launchAgents)")
                        statCard("LaunchDaemons", "\(vm.launchDaemons)")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DISABLED").font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.7)
                            Text("\(vm.disabledCount)").font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.warning)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 16).pareCard()
                    }
                    .padding(.bottom, 18)

                    // Filters
                    HStack {
                        HStack(spacing: 8) {
                            ForEach(["All", "Login Items", "LaunchAgents", "LaunchDaemons", "Disabled"], id: \.self) { f in
                                Button { vm.activeFilter = f } label: {
                                    Text(f).font(PareFont.body(12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 5)
                                        .background(vm.activeFilter == f ? PareColor.ink : PareColor.surface)
                                        .foregroundStyle(vm.activeFilter == f ? PareColor.bg : PareColor.ink2)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(vm.activeFilter == f ? PareColor.ink : PareColor.line, lineWidth: 1))
                                }.buttonStyle(.plain)
                            }
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Enabled:").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                            Text("\(vm.enabledCount)").font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink)
                            Text("\u{00B7} Disabled:").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                            Text("\(vm.disabledCount)").font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.warning)
                        }
                    }
                    .padding(.bottom, 18)

                    // Items table
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Color.clear.frame(width: 44)
                            Text("ITEM").frame(maxWidth: .infinity, alignment: .leading)
                            Text("TYPE").frame(width: 150, alignment: .leading)
                            Text("STATUS").frame(width: 60, alignment: .trailing)
                        }
                        .font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.6)
                        .padding(.horizontal, 18).padding(.vertical, 10).background(PareColor.surface2)

                        ForEach(vm.filteredItems) { item in
                            StartupRow(item: item) { newVal in
                                vm.toggleItem(item.id, enabled: newVal)
                            }
                        }
                    }
                    .background(PareColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                    .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
                    .padding(.bottom, 18)

                    HStack(spacing: 6) {
                        Image(systemName: "shield.checkered").font(.system(size: 12))
                        Text("Disabling an item only prevents it from auto-starting. The app still works when you open it manually.")
                    }.font(PareFont.body(12)).foregroundStyle(PareColor.forest)
                    .padding(12).background(PareColor.accentSoft).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.accentLine, lineWidth: 1))
                }
            }
            .padding(.horizontal, 40).padding(.vertical, 32)
        }
        .background(PareColor.bg)
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.7).textCase(.uppercase)
            Text(value).font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 16).pareCard()
    }
}

// MARK: - Startup Row

private struct StartupRow: View {
    let item: StartupEntry
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(String(item.name.prefix(1)))
                .font(PareFont.display(14, weight: .medium)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(item.iconColor).clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(.trailing, 14)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(PareFont.body(13, weight: .medium))
                        .foregroundStyle(item.isEnabled ? PareColor.ink : PareColor.ink3)
                    if !item.isEnabled {
                        Text("DISABLED").font(PareFont.mono(9, weight: .medium)).foregroundStyle(PareColor.warning)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(PareColor.warningSoft).clipShape(Capsule())
                    }
                }
                Text(item.path).font(PareFont.mono(11)).foregroundStyle(PareColor.ink4).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.type)
                    .font(PareFont.mono(10, weight: .medium))
                    .foregroundStyle(item.type == "LaunchDaemon" ? PareColor.warning : PareColor.forest)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(item.type == "LaunchDaemon" ? PareColor.warningSoft : PareColor.accentSoft)
                    .clipShape(Capsule())
                if !item.impact.isEmpty {
                    Text(item.impact).font(PareFont.mono(11)).foregroundStyle(item.isHighImpact ? PareColor.warning : PareColor.ink3)
                }
            }
            .frame(width: 150, alignment: .leading)

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .tint(PareColor.forest)
            .frame(width: 60)
            .disabled(item.isProtected)
            .opacity(item.isProtected ? 0.4 : 1)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(item.isProtected ? PareColor.surface2 : (!item.isEnabled ? PareColor.surface2.opacity(0.5) : Color.clear))
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - Model

struct StartupEntry: Identifiable {
    let id: String
    let name: String
    let path: String
    let plistURL: URL
    let type: String
    let impact: String
    let isHighImpact: Bool
    let isProtected: Bool
    let iconColor: Color
    var isEnabled: Bool
}

// MARK: - ViewModel

final class StartupItemsViewModel: ObservableObject {
    @Published var items: [StartupEntry] = []
    @Published var activeFilter: String = "All"
    @Published var isLoading = true

    private let defaults = UserDefaults.standard
    private let disabledKey = "pare.startup.disabled"

    var filteredItems: [StartupEntry] {
        switch activeFilter {
        case "Login Items":   return items.filter { $0.type == "Login Item" }
        case "LaunchAgents":  return items.filter { $0.type == "LaunchAgent" }
        case "LaunchDaemons": return items.filter { $0.type == "LaunchDaemon" }
        case "Disabled":      return items.filter { !$0.isEnabled }
        default: return items
        }
    }

    var loginItems: Int { items.filter { $0.type == "Login Item" }.count }
    var launchAgents: Int { items.filter { $0.type == "LaunchAgent" }.count }
    var launchDaemons: Int { items.filter { $0.type == "LaunchDaemon" }.count }
    var enabledCount: Int { items.filter(\.isEnabled).count }
    var disabledCount: Int { items.filter { !$0.isEnabled }.count }

    /// Persisted set of disabled plist paths
    private var disabledSet: Set<String> {
        get { Set(defaults.stringArray(forKey: disabledKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: disabledKey) }
    }

    init() { loadItems() }

    func toggleItem(_ id: String, enabled: Bool) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let entry = items[i]

        if enabled {
            // Re-enable: load the plist via launchctl
            enableAgent(entry.plistURL)
            var set = disabledSet
            set.remove(entry.plistURL.path)
            disabledSet = set
        } else {
            // Disable: unload the plist via launchctl
            disableAgent(entry.plistURL)
            var set = disabledSet
            set.insert(entry.plistURL.path)
            disabledSet = set
        }

        items[i].isEnabled = enabled
    }

    // MARK: - launchctl integration

    private func disableAgent(_ plistURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", "-w", plistURL.path]
        try? process.run()
        process.waitUntilExit()
    }

    private func enableAgent(_ plistURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", "-w", plistURL.path]
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Scan

    private func loadItems() {
        let vm = self
        let home = FileManager.default.homeDirectoryForCurrentUser
        let persistedDisabled = disabledSet

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let colors: [Color] = [
                .blue, .red, .green, .orange, .purple, .gray, .brown, .cyan,
                Color(red: 0.231, green: 0.353, blue: 0.549),
                Color(red: 0.722, green: 0.455, blue: 0.173),
            ]
            var entries: [StartupEntry] = []
            var colorIdx = 0

            // Scan user + system LaunchAgents
            for dir in [home.appendingPathComponent("Library/LaunchAgents"), URL(fileURLWithPath: "/Library/LaunchAgents")] {
                guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                for f in files where f.pathExtension == "plist" {
                    let label = f.deletingPathExtension().lastPathComponent
                    let displayName = Self.displayName(from: label)
                    let isUserDir = dir.path.contains(home.path)

                    // Check if plist has Disabled key
                    let plistDisabled = Self.isPlistDisabled(f)
                    let pareDisabled = persistedDisabled.contains(f.path)
                    let isEnabled = !plistDisabled && !pareDisabled

                    entries.append(StartupEntry(
                        id: f.path, name: displayName,
                        path: f.path.replacingOccurrences(of: home.path, with: "~"),
                        plistURL: f, type: "LaunchAgent",
                        impact: "", isHighImpact: false,
                        isProtected: !isUserDir && !fm.isWritableFile(atPath: f.path),
                        iconColor: colors[colorIdx % colors.count],
                        isEnabled: isEnabled
                    ))
                    colorIdx += 1
                }
            }

            // Scan LaunchDaemons
            for dir in [URL(fileURLWithPath: "/Library/LaunchDaemons")] {
                guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                for f in files where f.pathExtension == "plist" {
                    let label = f.deletingPathExtension().lastPathComponent
                    let displayName = Self.displayName(from: label)

                    let plistDisabled = Self.isPlistDisabled(f)
                    let pareDisabled = persistedDisabled.contains(f.path)

                    entries.append(StartupEntry(
                        id: f.path, name: displayName,
                        path: f.path, plistURL: f,
                        type: "LaunchDaemon", impact: "", isHighImpact: false,
                        isProtected: !fm.isWritableFile(atPath: f.path),
                        iconColor: colors[colorIdx % colors.count],
                        isEnabled: !plistDisabled && !pareDisabled
                    ))
                    colorIdx += 1
                }
            }

            // Mark known high-impact items
            let highImpact = ["adobe", "dropbox", "zoom", "teams", "spotify", "docker", "creative", "microsoft", "google"]
            for i in entries.indices {
                let lower = entries[i].name.lowercased()
                if highImpact.contains(where: { lower.contains($0) }) {
                    entries[i] = StartupEntry(
                        id: entries[i].id, name: entries[i].name, path: entries[i].path,
                        plistURL: entries[i].plistURL, type: entries[i].type,
                        impact: "+1.2s boot", isHighImpact: true, isProtected: entries[i].isProtected,
                        iconColor: entries[i].iconColor, isEnabled: entries[i].isEnabled
                    )
                }
            }

            // Sort: high impact first, then by name
            entries.sort {
                if $0.isHighImpact != $1.isHighImpact { return $0.isHighImpact }
                return $0.name < $1.name
            }

            DispatchQueue.main.async {
                vm.items = entries
                vm.isLoading = false
            }
        }
    }

    /// Read the plist to check if Disabled key is set
    private static func isPlistDisabled(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
        return plist["Disabled"] as? Bool ?? false
    }

    /// Extract a readable display name from a bundle-id style label
    private static func displayName(from label: String) -> String {
        let parts = label.split(separator: ".")
        if parts.count >= 3 {
            // e.g. "com.adobe.ccd" -> "Adobe Ccd" -> "Adobe CCD"
            let meaningful = parts.dropFirst(2).joined(separator: " ")
            return meaningful.prefix(1).uppercased() + meaningful.dropFirst()
        }
        if let last = parts.last {
            return String(last).prefix(1).uppercased() + String(last).dropFirst()
        }
        return label
    }
}
