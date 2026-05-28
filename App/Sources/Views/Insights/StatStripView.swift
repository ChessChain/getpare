// App/Sources/Views/Insights/StatStripView.swift

import SwiftUI

struct StatStripView: View {
    let stats: [InsightsViewModel.StatCard]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    Text(stat.label)
                        .font(PareFont.mono(10, weight: .medium))
                        .foregroundStyle(PareColor.ink3)
                        .tracking(0.8)
                    if stat.value == "Scanning..." {
                        ScanningPlaceholder()
                    } else {
                        Text(stat.value)
                            .font(PareFont.display(22, weight: .medium))
                            .foregroundStyle(PareColor.ink)
                    }
                    if stat.delta == "Calculating..." {
                        EmptyView()
                    } else {
                        Text(stat.delta)
                            .font(PareFont.body(12))
                            .foregroundStyle(stat.isWarning ? PareColor.warning : PareColor.ink3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .pareCard()
            }
        }
    }
}
