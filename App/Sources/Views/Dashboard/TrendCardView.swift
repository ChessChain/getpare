// App/Sources/Views/Dashboard/TrendCardView.swift

import SwiftUI
import Charts

struct TrendCardView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            // Left — meta
            VStack(alignment: .leading, spacing: 0) {
                // Label: "Storage used · 90-day trend"
                Text("Storage used \u{00B7} \(vm.selectedRange.label.lowercased()) trend")
                    .font(PareFont.mono(10, weight: .medium))
                    .foregroundStyle(PareColor.ink3)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .padding(.bottom, 4)

                // Big number: "412 GB / 512"
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(vm.usedGB) GB")
                        .font(PareFont.display(24, weight: .medium))
                        .tracking(-0.5)
                        .foregroundStyle(PareColor.ink)
                    Text("/ \(vm.capacityGB)")
                        .font(PareFont.mono(13))
                        .foregroundStyle(PareColor.ink3)
                }
                .padding(.bottom, 4)

                // Delta: "+ 14.2 GB this month"
                if !vm.trendDelta.isEmpty {
                    Text(vm.trendDelta)
                        .font(PareFont.mono(12))
                        .foregroundStyle(PareColor.warning)
                        .padding(.bottom, 4)
                }

                // Footnote: "3 cleanups in last 90 days"
                Text("\(CleanedItemStore.shared.totalCount) cleanup\(CleanedItemStore.shared.totalCount == 1 ? "" : "s") in last \(vm.selectedRange.days) days")
                    .font(PareFont.mono(11))
                    .foregroundStyle(PareColor.ink3)

                Spacer(minLength: 12)

                // Range switcher: [30D] [90D] [1YR]
                HStack(spacing: 0) {
                    ForEach(DashboardViewModel.TrendRange.allCases, id: \.self) { range in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { vm.selectedRange = range }
                        } label: {
                            Text(range.shortLabel.uppercased())
                                .font(PareFont.mono(11, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(vm.selectedRange == range ? PareColor.ink : Color.clear)
                                )
                                .foregroundStyle(vm.selectedRange == range ? PareColor.bg : PareColor.ink3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(PareColor.surface2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PareColor.line, lineWidth: 1))
            }
            .frame(width: 220, alignment: .topLeading)

            // Right — chart with gridlines + markers + axis
            if !vm.trendData.isEmpty {
                VStack(spacing: 0) {
                    Chart {
                        // Data
                        ForEach(vm.trendData) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("GB", point.gb)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [PareColor.forest.opacity(0.18), PareColor.forest.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("GB", point.gb)
                            )
                            .foregroundStyle(PareColor.forest)
                            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        }

                        // Cleanup markers (hollow circles)
                        ForEach(vm.cleanupMarkers) { marker in
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
                        }

                        // Today dot (filled)
                        if let last = vm.trendData.last {
                            PointMark(
                                x: .value("Date", last.date),
                                y: .value("GB", last.gb)
                            )
                            .symbol {
                                Circle()
                                    .fill(PareColor.forest)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                    // Horizontal gridlines only (3 lines)
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                                .foregroundStyle(PareColor.line)
                        }
                    }
                    .chartXAxis(.hidden)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)

                    // Axis labels below chart
                    HStack {
                        Text(vm.selectedRange.axisStart)
                        Spacer()
                        Text(vm.selectedRange.axisMid)
                        Spacer()
                        Text("TODAY")
                    }
                    .font(PareFont.mono(9, weight: .medium))
                    .foregroundStyle(PareColor.ink4)
                    .textCase(.uppercase)
                    .padding(.top, 6)
                }
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(PareColor.surface2)
                    .frame(maxWidth: .infinity, maxHeight: 140)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .pareCard()
    }
}
