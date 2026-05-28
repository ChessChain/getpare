// App/Sources/Views/Dashboard/StorageHeroView.swift

import SwiftUI

struct StorageHeroView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        HStack(spacing: 40) {
            // Left — numbers
            VStack(alignment: .leading, spacing: 0) {
                // "412 / 512 GB used"
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(vm.usedGB)")
                        .font(PareFont.display(56))
                        .tracking(-2)
                        .foregroundStyle(PareColor.ink)
                    Text("/ \(vm.capacityGB) GB used")
                        .font(PareFont.display(22))
                        .tracking(-0.5)
                        .foregroundStyle(PareColor.ink3)
                }

                // "RECLAIMABLE"
                Text("RECLAIMABLE")
                    .font(PareFont.mono(11, weight: .medium))
                    .foregroundStyle(PareColor.ink3)
                    .tracking(1)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                // "48.8 GB across N categories" — tappable, scrolls to recommendations
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(vm.reclaimableSummary)
                        .font(PareFont.display(24, weight: .medium))
                        .tracking(-0.5)
                        .foregroundStyle(PareColor.forest)
                    Text("across \(vm.reclaimableCategoryCount) categories")
                        .font(PareFont.body(14))
                        .italic()
                        .foregroundStyle(PareColor.ink3)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PareColor.ink4)
                }
                .contentShape(Rectangle())
                .onTapGesture { coordinator.route = .systemJunk } // go to first reclaimable category
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right — bar + legend
            VStack(alignment: .leading, spacing: 14) {
                StorageBar(segments: vm.barSegments, totalCapacity: vm.capacityBytes)

                // Legend — 2 columns, each item navigable
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(vm.legendItems) { item in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.label)
                                .font(PareFont.body(12))
                                .foregroundStyle(PareColor.ink2)
                            Spacer()
                            Text(item.sizeLabel)
                                .font(PareFont.mono(11))
                                .foregroundStyle(PareColor.ink3)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { navigateLegend(item.id) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .background(PareColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: PareRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: PareRadius.large)
                .stroke(PareColor.line, lineWidth: 1)
        )
    }

    private func navigateLegend(_ id: String) {
        switch id {
        case "apps":   coordinator.route = .uninstaller
        case "docs":   coordinator.route = .largeFiles
        case "media":  coordinator.route = .photos
        case "system": coordinator.route = .systemJunk
        case "other":  coordinator.route = .spaceLens
        case "free":   coordinator.route = .spaceLens
        default: break
        }
    }
}
