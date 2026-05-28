// App/Sources/Views/Insights/HeatmapView.swift

import SwiftUI

struct HeatmapView: View {
    let data: [[Int]]
    let dayLabels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cleanup activity")
                .font(PareFont.body(14, weight: .medium))
                .foregroundStyle(PareColor.ink)
            Text("Heatmap of the last 12 weeks. Darker squares mean more reclaimed that week.")
                .font(PareFont.body(12))
                .foregroundStyle(PareColor.ink3)

            VStack(spacing: 3) {
                ForEach(Array(data.enumerated()), id: \.offset) { rowIdx, row in
                    HStack(spacing: 3) {
                        Text(dayLabels[rowIdx])
                            .font(PareFont.mono(9))
                            .foregroundStyle(PareColor.ink4)
                            .frame(width: 28, alignment: .trailing)

                        ForEach(Array(row.enumerated()), id: \.offset) { _, intensity in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorForIntensity(intensity))
                                .frame(width: 14, height: 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(PareColor.line, lineWidth: intensity == 0 ? 1 : 0)
                                )
                        }
                    }
                }
            }
            .padding(.top, 8)

            // Legend
            HStack(spacing: 6) {
                Text("Less")
                    .font(PareFont.mono(9))
                    .foregroundStyle(PareColor.ink4)
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForIntensity(i))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(PareFont.mono(9))
                    .foregroundStyle(PareColor.ink4)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .pareCard()
    }

    private func colorForIntensity(_ i: Int) -> Color {
        switch i {
        case 0: return PareColor.surface2
        case 1: return PareColor.accentSoft
        case 2: return PareColor.forest.opacity(0.45)
        default: return PareColor.forest
        }
    }
}
