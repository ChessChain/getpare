// App/Sources/Views/Dashboard/CategoryCardView.swift

import SwiftUI

struct CategoryCardView: View {
    let recommendation: DashboardViewModel.CleanupRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon — 32x32, surface2 bg, 8px radius, ink2 color
            Image(systemName: recommendation.icon)
                .font(.system(size: 16))
                .foregroundStyle(PareColor.ink2)
                .frame(width: 32, height: 32)
                .background(PareColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 14)

            // Name — 14px, weight 500, ink
            Text(recommendation.name)
                .font(PareFont.body(14, weight: .medium))
                .foregroundStyle(PareColor.ink)
                .tracking(-0.07)
                .padding(.bottom, 4)

            // Description — 12px, ink3, min-height 32
            Text(recommendation.description)
                .font(PareFont.body(12))
                .foregroundStyle(PareColor.ink3)
                .lineSpacing(2)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 32, alignment: .top)
                .padding(.bottom, 14)

            Spacer(minLength: 0)

            // Size — display 22px ink + mono 11px ink3 "GB"
            sizeView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .background(PareColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
        .overlay(
            RoundedRectangle(cornerRadius: PareRadius.standard)
                .stroke(PareColor.line, lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) {
            if recommendation.isRecommended {
                Circle()
                    .fill(PareColor.forest)
                    .frame(width: 6, height: 6)
                    .padding(14)
            }
        }
        .hoverLift(3)
    }

    @ViewBuilder
    private var sizeView: some View {
        let label = recommendation.sizeLabel
        if label == "Scanning..." {
            ScanningPlaceholder()
        } else if label == "Scan needed" {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\u{2014}")
                    .font(PareFont.display(22, weight: .medium))
                    .foregroundStyle(PareColor.ink4)
                Text("  scan needed")
                    .font(PareFont.mono(11))
                    .foregroundStyle(PareColor.ink4)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        } else {
            // Parse "4.7 GB" into number + unit
            let parts = label.components(separatedBy: " ")
            if parts.count >= 2 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(parts[0])
                        .font(PareFont.display(22, weight: .medium))
                        .tracking(-0.5)
                        .foregroundStyle(PareColor.ink)
                    Text(parts[1].uppercased())
                        .font(PareFont.mono(11))
                        .foregroundStyle(PareColor.ink3)
                        .tracking(0.5)
                }
            } else {
                Text(label)
                    .font(PareFont.display(22, weight: .medium))
                    .foregroundStyle(PareColor.ink)
            }
        }
    }
}
