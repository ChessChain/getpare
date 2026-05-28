// App/Sources/Views/Scan/ScanRingView.swift

import SwiftUI

struct ScanRingView: View {
    let percent: Double
    let status: String

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(PareColor.line, lineWidth: 4)

            // Fill
            Circle()
                .trim(from: 0, to: percent)
                .stroke(PareColor.forest, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: percent)

            // Center text
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(Int(percent * 100))")
                        .font(PareFont.display(48, weight: .medium))
                        .foregroundStyle(PareColor.ink)
                    Text("%")
                        .font(PareFont.display(22))
                        .foregroundStyle(PareColor.ink3)
                }
                Text(status.uppercased())
                    .font(PareFont.mono(11, weight: .medium))
                    .foregroundStyle(PareColor.ink3)
                    .tracking(1.2)
            }
        }
        .frame(width: 220, height: 220)
    }
}
