// App/Sources/Views/Categories/UninstallerView.swift

import SwiftUI

struct UninstallerView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = UninstallerViewModel()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Uninstaller").italic()
                                    .font(PareFont.display(30))
                                    .foregroundStyle(PareColor.ink)
                                Text("Remove an app together with its preferences, caches, and support files. Pare also surfaces leftovers from apps you\u{2019}ve already deleted.")
                                    .font(PareFont.body(13))
                                    .foregroundStyle(PareColor.ink3)
                            }
                            Spacer()
                            Button { coordinator.route = .dashboard } label: {
                                Text("Back")
                                    .font(PareFont.body(13, weight: .medium))
                                    .foregroundStyle(PareColor.ink2)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 20)
                        Divider().padding(.bottom, 22)

                        // Scan progress
                        if vm.isLoading {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Circle().fill(PareColor.forest).frame(width: 6, height: 6).modifier(PulseMod())
                                    Text(vm.scanTask).font(PareFont.mono(10)).foregroundStyle(PareColor.ink3)
                                    Spacer()
                                    Text("\(Int(vm.scanProgress * 100))%").font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.forest)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(PareColor.line)
                                        RoundedRectangle(cornerRadius: 3).fill(PareColor.forest)
                                            .frame(width: geo.size.width * vm.scanProgress)
                                            .animation(.easeInOut(duration: 0.3), value: vm.scanProgress)
                                    }
                                }
                                .frame(height: 4)
                            }
                            .padding(.bottom, 18)
                        }

                        // Filter pills
                        HStack {
                            HStack(spacing: 8) {
                                filterPill("Installed apps")
                                filterPill("Leftover data (\(vm.leftovers.count))")
                                filterPill("Large apps")
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Text("Selected:").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                                Text("\(vm.selectedCount)").font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink)
                                Text("apps \u{00B7} Reclaiming:").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                                Text(vm.selectedSizeLabel).font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink)
                            }
                        }
                        .padding(.bottom, 18)

                        // Installed apps list
                        if vm.activeFilter != "Leftover data (\(vm.leftovers.count))" {
                            VStack(spacing: 0) {
                                ForEach(vm.displayedApps) { app in
                                    AppRow(app: app, isLeftover: false) {
                                        vm.toggleApp(app.id)
                                    }
                                }
                            }
                            .background(PareColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                            .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
                            .padding(.bottom, 16)
                        }

                        // Leftover data section
                        if !vm.leftovers.isEmpty && vm.activeFilter != "Large apps" {
                            Text("Leftover Data (apps you\u{2019}ve already deleted)")
                                .font(PareFont.display(13, weight: .medium))
                                .foregroundStyle(PareColor.ink3)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.top, 8)
                                .padding(.bottom, 16)

                            VStack(spacing: 0) {
                                ForEach(vm.leftovers) { app in
                                    AppRow(app: app, isLeftover: true) {
                                        vm.toggleLeftover(app.id)
                                    }
                                }
                            }
                            .background(PareColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                            .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 32)
                    .padding(.bottom, 100)
                }

                // Sticky footer
                HStack {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(vm.selectedSizeLabel)
                            .font(PareFont.display(24, weight: .medium))
                            .foregroundStyle(PareColor.ink)
                        Text("will be moved to Recovery Bin")
                            .font(PareFont.body(12))
                            .foregroundStyle(PareColor.ink3)
                    }
                    Spacer()
                    Button { vm.selectAll() } label: {
                        Text("Select all").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink3).padding(.horizontal, 10).padding(.vertical, 6)
                    }.buttonStyle(.plain)
                    Button { vm.deselectAll() } label: {
                        Text("Deselect all").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink3).padding(.horizontal, 10).padding(.vertical, 6)
                    }.buttonStyle(.plain)
                    Button { vm.reviewAndClean() } label: {
                        Text("Review & Clean").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white).padding(.horizontal, 20).padding(.vertical, 10).background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 40).padding(.vertical, 18)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) { Divider() }
            }
            .background(PareColor.bg)

            if vm.showConfirm { confirmModal }
            if vm.showSuccess { successOverlay }
            if vm.showPaywall { PaywallModal(isPresented: $vm.showPaywall) }
        }
    }

    private func filterPill(_ label: String) -> some View {
        Button {
            vm.activeFilter = label
        } label: {
            Text(label)
                .font(PareFont.body(12, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(vm.activeFilter == label ? PareColor.ink : PareColor.surface)
                .foregroundStyle(vm.activeFilter == label ? PareColor.bg : PareColor.ink2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(vm.activeFilter == label ? PareColor.ink : PareColor.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Confirm Modal

    private var confirmModal: some View {
        let selected = vm.displayedApps.filter(\.isSelected) + vm.leftovers.filter(\.isSelected)
        let totalResiduePaths = selected.reduce(0) { $0 + $1.residuePaths.count }

        return ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { vm.cancelClean() }
            VStack(alignment: .leading, spacing: 0) {
                Text("Uninstall \(vm.selectedCount) app\(vm.selectedCount == 1 ? "" : "s")?")
                    .font(PareFont.display(22)).foregroundStyle(PareColor.ink).padding(.bottom, 10)

                Text("The app bundle and all associated data will be removed. The .app is moved to the Recovery Bin (restorable for 30 days); residue files are deleted immediately.")
                    .font(PareFont.body(13)).foregroundStyle(PareColor.ink2).lineSpacing(3).padding(.bottom, 16)

                // Detail box
                VStack(spacing: 4) {
                    detailRow("Apps to remove", "\(vm.selectedCount)")
                    detailRow("App bundles", AppEntry.fmt(selected.reduce(0) { $0 + $1.appBytes }))
                    detailRow("Residue files", "\(totalResiduePaths) paths \u{00B7} \(AppEntry.fmt(selected.reduce(0) { $0 + $1.residueBytes }))")
                    detailRow("Total space freed", vm.selectedSizeLabel)
                }
                .padding(14).background(PareColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1))
                .padding(.bottom, 14)

                // What will be removed
                if selected.count <= 5 {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(selected) { app in
                            HStack(spacing: 8) {
                                Text(String(app.name.prefix(1))).font(PareFont.display(11, weight: .medium)).foregroundStyle(.white)
                                    .frame(width: 20, height: 20).background(app.iconColor).clipShape(RoundedRectangle(cornerRadius: 5))
                                Text(app.name).font(PareFont.body(12, weight: .medium)).foregroundStyle(PareColor.ink)
                                Spacer()
                                Text(app.totalLabel).font(PareFont.mono(11)).foregroundStyle(PareColor.ink3)
                            }
                        }
                    }
                    .padding(12).background(PareColor.surface2).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1))
                    .padding(.bottom, 14)
                }

                // Reassurance
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered").font(.system(size: 12))
                    Text("App bundle goes to Recovery Bin. Residue (caches, prefs, logs) is deleted permanently.")
                        .font(PareFont.body(12))
                }
                .foregroundStyle(PareColor.forest).padding(12)
                .background(PareColor.accentSoft).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.accentLine, lineWidth: 1))
                .padding(.bottom, 20)

                HStack {
                    Spacer()
                    Button { vm.cancelClean() } label: {
                        Text("Cancel").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }.buttonStyle(.plain)
                    Button { vm.confirmClean() } label: {
                        Text("Uninstall").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(PareColor.danger).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            .padding(32).frame(maxWidth: 480).background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 40, y: 12)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(PareFont.mono(12)).foregroundStyle(PareColor.ink2)
            Spacer()
            Text(value).font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink)
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(PareColor.accentSoft).frame(width: 64, height: 64)
                    Image(systemName: "checkmark").font(.system(size: 28, weight: .medium)).foregroundStyle(PareColor.forest)
                }
                Text("Uninstalled \(vm.cleanedCount) app\(vm.cleanedCount == 1 ? "" : "s")")
                    .font(PareFont.display(28)).foregroundStyle(PareColor.ink)
                Text("\(AppEntry.fmt(vm.cleanedSize)) freed. App bundles are in the Recovery Bin for 30 days.")
                    .font(PareFont.body(14)).foregroundStyle(PareColor.ink3).multilineTextAlignment(.center).frame(maxWidth: 360)
                HStack(spacing: 12) {
                    Button { vm.showSuccess = false; coordinator.route = .recovery } label: {
                        Text("View Recovery Bin").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }.buttonStyle(.plain)
                    Button { vm.showSuccess = false; coordinator.route = .dashboard } label: {
                        Text("Back to Dashboard").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            .padding(40).background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 40, y: 12)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))
        }
    }
}

// MARK: - App Row

private struct AppRow: View {
    let app: AppEntry
    var isLeftover: Bool = false
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Checkbox
            ZStack {
                RoundedRectangle(cornerRadius: 4).stroke(app.isSelected ? PareColor.ink : PareColor.lineStrong, lineWidth: 1.5).frame(width: 16, height: 16)
                if app.isSelected {
                    RoundedRectangle(cornerRadius: 4).fill(PareColor.ink).frame(width: 16, height: 16)
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(PareColor.bg)
                }
            }
            .frame(width: 28)
            .padding(.trailing, 14)

            // App icon
            Text(String(app.name.prefix(1)))
                .font(PareFont.display(16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(app.iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.trailing, 14)

            // Name + meta
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(PareFont.body(13, weight: .medium))
                        .foregroundStyle(PareColor.ink)
                    if isLeftover {
                        Text("(uninstalled)")
                            .font(PareFont.body(11))
                            .italic()
                            .foregroundStyle(PareColor.ink3)
                    }
                }
                Text(app.meta)
                    .font(PareFont.mono(11))
                    .foregroundStyle(PareColor.ink3)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Residue info
            if isLeftover {
                HStack(spacing: 2) {
                    Text("Residue:").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                    Text(app.residueLabel).font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink)
                }
            } else {
                HStack(spacing: 2) {
                    Text("App:").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                    Text(app.appSizeLabel).font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink)
                    Text("\u{00B7}").foregroundStyle(PareColor.ink3)
                    Text("Residue:").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                    Text(app.residueLabel).font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink)
                }
            }

            // Total size
            Text(app.totalLabel)
                .font(PareFont.mono(12, weight: .medium))
                .foregroundStyle(PareColor.ink3)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct PulseMod: ViewModifier {
    @State private var p = false
    func body(content: Content) -> some View {
        content.scaleEffect(p ? 1.3 : 1).opacity(p ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: p)
            .onAppear { p = true }
    }
}
