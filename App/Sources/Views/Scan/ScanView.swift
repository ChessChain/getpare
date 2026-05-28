// App/Sources/Views/Scan/ScanView.swift

import SwiftUI
import PareKit

struct ScanView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = ScanViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    (Text(vm.isScanning ? "Scanning " : "Smart ") + Text(vm.isScanning ? "your Mac" : "Scan").italic())
                        .font(PareFont.display(30))
                        .foregroundStyle(PareColor.ink)
                    Text("All analysis happens on your device. Nothing leaves your Mac.")
                        .font(PareFont.body(13))
                        .foregroundStyle(PareColor.ink3)
                }
                Spacer()
                if vm.isScanning {
                    Button {
                        vm.cancelScan()
                        coordinator.route = .dashboard
                    } label: {
                        Text("Cancel")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                } else if vm.scanComplete {
                    Button {
                        coordinator.route = .dashboard
                    } label: {
                        Text("Back to Dashboard")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(PareColor.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 32)
            .padding(.bottom, 20)

            Divider().padding(.horizontal, 40)

            Spacer()

            // Scan ring
            ScanRingView(percent: vm.percent, status: vm.isScanning ? "Scanning" : (vm.scanComplete ? "Complete" : "Ready"))
                .padding(.bottom, 24)

            // Task info
            Text(vm.currentTask)
                .font(PareFont.body(14))
                .foregroundStyle(PareColor.ink2)
                .padding(.bottom, 4)

            Text(vm.currentPath)
                .font(PareFont.mono(11))
                .foregroundStyle(PareColor.ink4)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 400)
                .frame(height: 16)
                .padding(.bottom, 28)

            // Scan mode + start
            if !vm.isScanning && !vm.scanComplete {
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        scanModeButton("Standard", mode: .standard)
                        scanModeButton("Deep Scan", mode: .deep)
                    }
                    .padding(3)
                    .background(PareColor.surface2)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PareColor.line, lineWidth: 1))

                    Text(vm.scanMode == .standard
                         ? "Scans user directories: caches, downloads, mail, developer tools."
                         : "Full system scan: /Applications, all ~/Library paths, hashing for duplicates. Slower but thorough.")
                        .font(PareFont.mono(11))
                        .foregroundStyle(PareColor.ink4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .padding(.bottom, 20)

                Button {
                    vm.startRealScan()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: vm.scanMode == .deep ? "magnifyingglass.circle.fill" : "magnifyingglass")
                            .font(.system(size: 12, weight: .medium))
                        Text(vm.scanMode == .deep ? "Start Deep Scan" : "Start Scan")
                    }
                    .font(PareFont.body(14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(PareColor.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 28)
            }

            Spacer()

            // Stat cards
            HStack(spacing: 12) {
                ScanStatCard(label: "FILES SCANNED", value: vm.filesScanned.formatted())
                ScanStatCard(label: "RECLAIMABLE", value: vm.foundSoFarFormatted, isAccent: true)
                ScanStatCard(label: "EST. TIME LEFT", value: vm.estimatedTimeLeft)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PareColor.bg)
    }

    private func scanModeButton(_ label: String, mode: ScanViewModel.ScanMode) -> some View {
        Button { vm.scanMode = mode } label: {
            Text(label)
                .font(PareFont.mono(11, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(vm.scanMode == mode ? PareColor.ink : Color.clear)
                .foregroundStyle(vm.scanMode == mode ? PareColor.bg : PareColor.ink3)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Card

private struct ScanStatCard: View {
    let label: String
    let value: String
    var isAccent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(PareFont.mono(10, weight: .medium))
                .foregroundStyle(PareColor.ink3)
                .tracking(0.8)
            Text(value)
                .font(PareFont.display(22, weight: .medium))
                .tracking(-0.4)
                .foregroundStyle(isAccent ? PareColor.forest : PareColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PareColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1)
        )
    }
}
