// App/Sources/Views/Insights/StorageOverTimeChart.swift

import SwiftUI
import Charts

struct StorageOverTimeChart: View {
    let data: [InsightsViewModel.StoragePoint]
    let markers: [InsightsViewModel.CleanupMarker]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(markers.isEmpty ? "Current disk usage" : "Storage used over time")
                .font(PareFont.body(14, weight: .medium))
                .foregroundStyle(PareColor.ink)
            Text(chartSubtitle)
                .font(PareFont.body(12))
                .foregroundStyle(PareColor.ink3)

            Chart {
                ForEach(data) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("GB", point.gb)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PareColor.forest.opacity(0.25), PareColor.forest.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("GB", point.gb)
                    )
                    .foregroundStyle(PareColor.forest)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }

                // Capacity warning line
                RuleMark(y: .value("Capacity", 512))
                    .foregroundStyle(PareColor.warning.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("512 GB capacity")
                            .font(PareFont.mono(9))
                            .foregroundStyle(PareColor.warning)
                    }

                // Cleanup markers
                ForEach(markers) { marker in
                    PointMark(
                        x: .value("Date", marker.date),
                        y: .value("GB", marker.gb)
                    )
                    .symbol {
                        Circle()
                            .fill(PareColor.bg)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(PareColor.forest, lineWidth: 2))
                    }
                    .annotation(position: .top) {
                        Text(marker.label)
                            .font(PareFont.mono(9))
                            .foregroundStyle(PareColor.forest)
                    }
                }
            }
            .chartYScale(domain: 200...530)
            .chartYAxis {
                AxisMarks(values: [200, 300, 400, 500]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        .foregroundStyle(PareColor.line)
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v) GB").font(PareFont.mono(9)).foregroundStyle(PareColor.ink4)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).year(.twoDigits))
                                .font(PareFont.mono(9))
                                .foregroundStyle(PareColor.ink4)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(20)
        .pareCard()
    }

    private var chartSubtitle: String {
        guard let first = data.first, let last = data.last else { return "" }
        let usedGB = Int(last.gb)
        if markers.isEmpty {
            return "\(usedGB) GB used. Clean files to see changes over time."
        } else {
            return "\(usedGB) GB used. \(markers.count) cleanup\(markers.count == 1 ? "" : "s") visible."
        }
    }
}
