// App/Sources/Views/Account/ProfileView.swift

import SwiftUI
import AppKit

struct ProfileView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var store = CleanedItemStore.shared
    @ObservedObject private var licence = LicenceManager.shared
    @State private var showResetConfirm = false

    private var userName: String { NSFullUserName().components(separatedBy: " ").first ?? "User" }
    private var fullName: String { NSFullUserName() }
    private var macName: String { Host.current().localizedName ?? "This Mac" }
    private var macOS: String { "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)" }
    private var memberSince: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        // Use the earliest cleanup date, or fall back to app first launch
        if let earliest = store.items.last?.cleanedDate {
            return fmt.string(from: earliest)
        }
        return fmt.string(from: Date())
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Profile").italic().font(PareFont.display(30)).foregroundStyle(PareColor.ink)
                            Text("Your Pare licence and this Mac.").font(PareFont.body(13)).foregroundStyle(PareColor.ink3)
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

                    HStack(alignment: .top, spacing: 24) {
                        // Left card
                        VStack(spacing: 0) {
                            Text(String(userName.prefix(1)))
                                .font(PareFont.display(36, weight: .medium)).foregroundStyle(.white)
                                .frame(width: 88, height: 88)
                                .background(LinearGradient(colors: [Color(red: 0.106, green: 0.369, blue: 0.247), Color(red: 0.173, green: 0.373, blue: 0.290)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(Circle())
                                .padding(.bottom, 16)

                            Text(fullName).font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.ink).padding(.bottom, 14)

                            HStack(spacing: 6) {
                                Image(systemName: licence.isPremium ? "star.fill" : "star").font(.system(size: 11))
                                Text(licence.isPremium ? "Premium" : "Free tier")
                            }
                            .font(PareFont.mono(11, weight: .medium)).foregroundStyle(PareColor.forest)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(PareColor.accentSoft).clipShape(Capsule())
                            .overlay(Capsule().stroke(PareColor.accentLine, lineWidth: 1))
                            .padding(.bottom, 22)

                            Divider().padding(.bottom, 18)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                pqsCell("RECLAIMED", store.totalCount > 0 ? store.totalSizeLabel : "0 KB")
                                pqsCell("MEMBER SINCE", memberSince)
                                pqsCell("CLEANUPS", "\(store.totalCount)")
                                pqsCell("THIS MONTH", licence.usageLabel)
                            }
                        }
                        .padding(24).frame(width: 280).multilineTextAlignment(.center)
                        .background(PareColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))

                        // Right sections
                        VStack(spacing: 14) {
                            // This Mac
                            profileSection("This Mac") {
                                HStack(spacing: 14) {
                                    Image(systemName: "laptopcomputer").font(.system(size: 18)).foregroundStyle(PareColor.ink2)
                                        .frame(width: 34, height: 34).background(PareColor.surface2)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(macName).font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                                        Text("Apple Silicon \u{00B7} \(macOS)").font(PareFont.mono(11)).foregroundStyle(PareColor.ink3)
                                    }
                                    Spacer()
                                    Text("ACTIVE").font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.forest)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(PareColor.accentSoft).clipShape(Capsule())
                                        .overlay(Capsule().stroke(PareColor.accentLine, lineWidth: 1))
                                }
                                .padding(.vertical, 12)
                            }

                            // Licence
                            profileSection("Licence") {
                                if licence.isPremium {
                                    profileRow("Status", "Active \u{2014} Premium, unlimited cleanup") { EmptyView() }
                                    profileRow("Key", licence.licenceKey) { EmptyView() }
                                    if !licence.licenceEmail.isEmpty {
                                        profileRow("Email", licence.licenceEmail) { EmptyView() }
                                    }
                                    profileRowLast("Deactivate", "Move this licence to another Mac.") {
                                        dangerBtn("Deactivate") { licence.deactivate() }
                                    }
                                } else {
                                    profileRow("Status", "Free \u{2014} 500 MB/month cleanup cap") { EmptyView() }
                                    profileRow("Usage", "\(licence.usageLabel) used this month") {
                                        // Usage bar
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3).fill(PareColor.line).frame(width: 100, height: 6)
                                            RoundedRectangle(cornerRadius: 3).fill(licence.isOverLimit ? PareColor.warning : PareColor.forest)
                                                .frame(width: max(1, 100 * licence.usagePercent), height: 6)
                                        }
                                    }
                                    profileRowLast("Upgrade", "Purchase a licence key to unlock unlimited cleanup.") {
                                        Button { coordinator.route = .settings } label: {
                                            Text("Enter Key").font(PareFont.body(11, weight: .medium)).foregroundStyle(.white)
                                                .padding(.horizontal, 12).padding(.vertical, 4)
                                                .background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 6))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }

                            // Data & Privacy
                            profileSection("Data & Privacy") {
                                profileRow("Storage location", "~/Library/Application Support/Pare") {
                                    smallBtn("Show in Finder") {
                                        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Pare")
                                        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
                                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
                                    }
                                }
                                profileRow("Recovery Bin", "\(store.totalCount) items \u{00B7} \(store.totalSizeLabel)") {
                                    smallBtn("View") { coordinator.route = .recovery }
                                }
                                profileRowLast("Reset Pare", "Clear all preferences. Recovery Bin and licence are preserved.") {
                                    dangerBtn("Reset\u{2026}") { showResetConfirm = true }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 40).padding(.vertical, 32)
            }
            .background(PareColor.bg)

            if showResetConfirm { resetModal }
        }
    }

    // MARK: - Reset Modal

    private var resetModal: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { showResetConfirm = false }
            VStack(alignment: .leading, spacing: 16) {
                Text("Reset all preferences?").font(PareFont.display(22)).foregroundStyle(PareColor.ink)
                Text("This restores every setting to its default value. Your Recovery Bin and licence key are preserved.")
                    .font(PareFont.body(13)).foregroundStyle(PareColor.ink2).lineSpacing(3)
                HStack {
                    Spacer()
                    Button { showResetConfirm = false } label: {
                        Text("Cancel").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }.buttonStyle(.plain)
                    Button {
                        SettingsStore.shared.resetAll()
                        showResetConfirm = false
                    } label: {
                        Text("Reset").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(PareColor.danger).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            .padding(32).frame(maxWidth: 420).background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 40, y: 12)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))
        }
    }

    // MARK: - Helpers

    private func pqsCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.6)
            Text(value).font(PareFont.display(18, weight: .medium)).foregroundStyle(PareColor.ink)
        }
    }

    private func profileSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(PareFont.display(16, weight: .medium)).foregroundStyle(PareColor.ink).padding(.bottom, 14)
            content()
        }
        .padding(22).background(PareColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
    }

    private func profileRow(_ label: String, _ hint: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                Text(hint).font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
            }.frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func profileRowLast(_ label: String, _ hint: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                Text(hint).font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
            }.frame(maxWidth: .infinity, alignment: .leading)
            control()
        }.padding(.vertical, 14)
    }

    private func smallBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(PareFont.body(11, weight: .medium)).foregroundStyle(PareColor.ink2)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(PareColor.lineStrong, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func dangerBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(PareFont.body(11, weight: .medium)).foregroundStyle(PareColor.danger)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.831, green: 0.690, blue: 0.690), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
