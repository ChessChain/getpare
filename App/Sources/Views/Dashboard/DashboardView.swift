// App/Sources/Views/Dashboard/DashboardView.swift

import SwiftUI
import PareKit

struct DashboardView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Pane header ──────────────────────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        (Text(Self.timeOfDayGreeting + " ") + Text(vm.userName).italic())
                            .font(PareFont.display(30))
                            .foregroundStyle(PareColor.ink)
                        HStack(spacing: 0) {
                            Text("Your Mac has ")
                                .font(PareFont.body(13))
                                .foregroundStyle(PareColor.ink3)
                            Text(vm.reclaimableSummary)
                                .font(PareFont.body(13, weight: .medium))
                                .foregroundStyle(PareColor.forest)
                            Text(" of reclaimable space.")
                                .font(PareFont.body(13))
                                .foregroundStyle(PareColor.ink3)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { coordinator.route = .systemJunk }
                        if !vm.lastScanLabel.isEmpty {
                            HStack(spacing: 10) {
                                Text(vm.lastScanLabel)
                                    .font(PareFont.mono(11))
                                    .foregroundStyle(PareColor.ink4)
                                Text("STALE \u{00B7} RESCAN SUGGESTED")
                                    .font(PareFont.mono(10, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(PareColor.warning)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(PareColor.warningSoft)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(Color(red: 0.894, green: 0.784, blue: 0.588), lineWidth: 1) // #E4C896
                                    )
                            }
                            .padding(.top, 4)
                        }
                    }
                    Spacer()
                    Button {
                        coordinator.startScan()
                    } label: {
                        HStack(spacing: 6) {
                            if vm.isScanning {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            Text(vm.isScanning ? "Scanning..." : "Run Smart Scan")
                        }
                        .font(PareFont.body(13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(vm.isScanning ? PareColor.ink.opacity(0.7) : PareColor.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isScanning)
                }
                .padding(.bottom, 24)

                // ── FDA Banner ───────────────────────────────────────────
                if !PermissionManager.shared.hasFullDiskAccess {
                    FDABannerView()
                        .padding(.bottom, 12)
                }

                // ── Scan Progress ────────────────────────────────────────
                DiskScanProgressBar()
                    .padding(.bottom, 8)

                // ── Storage Hero ─────────────────────────────────────────
                StorageHeroView(vm: vm)
                    .padding(.bottom, 28)

                // ── Trend Card ───────────────────────────────────────────
                TrendCardView(vm: vm)
                    .padding(.bottom, 28)

                // ── Recommended Cleanups ─────────────────────────────────
                Text("Recommended Cleanups")
                    .font(PareFont.display(13, weight: .medium))
                    .foregroundStyle(PareColor.ink3)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .padding(.bottom, 16)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(vm.recommendations) { rec in
                        CategoryCardView(recommendation: rec)
                            .onTapGesture { navigateToCategory(rec.id) }
                    }
                }
            }
            .padding(.horizontal, PareSpacing.xxl)
            .padding(.vertical, PareSpacing.xl)
        }
        .background(PareColor.bg)
    }
}

private extension DashboardView {
    func navigateToCategory(_ id: String) {
        switch id {
        case "dup":   coordinator.route = .duplicates
        case "dev":   coordinator.route = .developerJunk
        case "cache": coordinator.route = .systemJunk
        case "dl":    coordinator.route = .downloads
        case "large": coordinator.route = .largeFiles
        case "app":   coordinator.route = .uninstaller
        case "mail":  coordinator.route = .mailCleanup
        default: break
        }
    }

    static var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<21: return "Good evening,"
        default:      return "Good evening,"
        }
    }
}
