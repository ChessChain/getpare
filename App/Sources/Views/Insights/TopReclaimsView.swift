// App/Sources/Views/Insights/TopReclaimsView.swift

import SwiftUI

struct TopReclaimsView: View {
    let reclaims: [InsightsViewModel.ReclaimEntry]

    private var hasHistory: Bool {
        CleanedItemStore.shared.totalCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hasHistory ? "Top reclaims" : "Reclaimable by category")
                .font(PareFont.body(14, weight: .medium))
                .foregroundStyle(PareColor.ink)
            Text(hasHistory ? "Your largest cleanups." : "What you can free up right now.")
                .font(PareFont.body(12))
                .foregroundStyle(PareColor.ink3)

            VStack(spacing: 0) {
                ForEach(reclaims) { entry in
                    HStack(spacing: 0) {
                        Text(entry.date)
                            .font(PareFont.mono(11))
                            .foregroundStyle(PareColor.ink3)
                            .textCase(.uppercase)
                            .frame(width: 60, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.category)
                                .font(PareFont.body(13, weight: .medium))
                                .foregroundStyle(PareColor.ink)
                            Text(entry.detail)
                                .font(PareFont.mono(11))
                                .foregroundStyle(PareColor.ink3)
                                .lineLimit(1)
                        }

                        Spacer()

                        if entry.amount == "Scanning..." {
                            ScanningPlaceholder()
                        } else {
                            Text(entry.amount)
                                .font(PareFont.mono(13, weight: .medium))
                                .foregroundStyle(PareColor.forest)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .overlay(alignment: .bottom) {
                        if entry.id != reclaims.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
            .background(PareColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: PareRadius.small))
        }
        .padding(20)
        .pareCard()
    }
}
