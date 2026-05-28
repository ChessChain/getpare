// App/Sources/Views/Insights/InsightsView.swift

import SwiftUI

struct InsightsView: View {
    @StateObject private var vm = InsightsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PaneHeader(
                    title: "Insights",
                    accent: "& trends",
                    subtitle: "How storage on this Mac has changed over time, what Pare has reclaimed, and which categories are growing fastest."
                )

                DiskScanProgressBar()

                StatStripView(stats: vm.stats)

                // Charts row: storage over time + donut
                HStack(alignment: .top, spacing: 18) {
                    StorageOverTimeChart(data: vm.storageOverTime, markers: vm.cleanupMarkers)
                        .frame(maxWidth: .infinity)
                    DonutChartView(segments: vm.donutSegments, total: vm.donutTotal, usedLabel: vm.donutUsedLabel)
                        .frame(width: 320)
                }

                // Bottom row: top reclaims + heatmap
                HStack(alignment: .top, spacing: 18) {
                    TopReclaimsView(reclaims: vm.topReclaims)
                        .frame(maxWidth: .infinity)
                    HeatmapView(data: vm.heatmapData, dayLabels: vm.heatmapDays)
                        .frame(width: 320)
                }

                // Privacy footer
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11))
                    Text("All Insights data is derived from your local scan history \u{2014} nothing is sent to ClearPath Digital.")
                }
                .font(PareFont.mono(11))
                .foregroundStyle(PareColor.ink4)
                .padding(.top, 8)
            }
            .padding(PareSpacing.xl)
        }
        .background(PareColor.bg)
    }
}
