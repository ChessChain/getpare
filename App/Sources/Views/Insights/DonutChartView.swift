// App/Sources/Views/Insights/DonutChartView.swift

import SwiftUI

struct DonutChartView: View {
    let segments: [InsightsViewModel.DonutSegment]
    let total: Double
    var usedLabel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where space is going")
                .font(PareFont.body(14, weight: .medium))
                .foregroundStyle(PareColor.ink)
            Text("Share of disk by category, today.")
                .font(PareFont.body(12))
                .foregroundStyle(PareColor.ink3)

            HStack {
                Spacer()
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(PareColor.line, lineWidth: 28)
                        .frame(width: 160, height: 160)

                    // Data rings
                    ForEach(Array(segmentAngles.enumerated()), id: \.offset) { index, seg in
                        Circle()
                            .trim(from: seg.start, to: seg.end)
                            .stroke(segments[index].color, style: StrokeStyle(lineWidth: 28, lineCap: .butt))
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))
                    }

                    // Center label
                    VStack(spacing: 2) {
                        Text(usedLabel.isEmpty ? "\(Int(total)) GB" : usedLabel)
                            .font(PareFont.display(16, weight: .medium))
                            .foregroundStyle(PareColor.ink)
                        Text("USED")
                            .font(PareFont.mono(8, weight: .medium))
                            .foregroundStyle(PareColor.ink3)
                            .tracking(1.2)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)

            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(segments) { seg in
                    HStack(spacing: 6) {
                        Circle().fill(seg.color).frame(width: 8, height: 8)
                        Text(seg.name)
                            .font(PareFont.body(11))
                            .foregroundStyle(PareColor.ink2)
                        Spacer()
                        Text("\(Int(seg.gb)) GB")
                            .font(PareFont.mono(11))
                            .foregroundStyle(PareColor.ink3)
                    }
                }
            }
        }
        .padding(20)
        .pareCard()
    }

    private var segmentAngles: [(start: CGFloat, end: CGFloat)] {
        var cumulative: CGFloat = 0
        return segments.map { seg in
            let fraction = CGFloat(seg.gb / total)
            let start = cumulative
            cumulative += fraction
            return (start, cumulative)
        }
    }
}
