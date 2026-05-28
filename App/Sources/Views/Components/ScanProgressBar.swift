// App/Sources/Views/Components/DiskScanProgressBar.swift

import SwiftUI

/// A compact progress bar that shows scan status inline.
/// Used in Dashboard cards and Insights stat cards while directories are being scanned.
struct DiskScanProgressBar: View {
    @ObservedObject private var scan = DiskScanProgress.shared

    var body: some View {
        if scan.isScanning {
            VStack(alignment: .leading, spacing: 6) {
                // Task label
                HStack(spacing: 6) {
                    ProgressDot()
                    Text(scan.currentTask)
                        .font(PareFont.mono(10))
                        .foregroundStyle(PareColor.ink3)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(scan.progress * 100))%")
                        .font(PareFont.mono(10, weight: .medium))
                        .foregroundStyle(PareColor.forest)
                }

                // Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(PareColor.line)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(PareColor.forest)
                            .frame(width: geo.size.width * scan.progress)
                            .animation(.easeInOut(duration: 0.35), value: scan.progress)
                    }
                }
                .frame(height: 4)
            }
        }
    }
}

/// Animated pulsing dot to indicate active scanning
private struct ProgressDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(PareColor.forest)
            .frame(width: 6, height: 6)
            .scaleEffect(pulse ? 1.3 : 1.0)
            .opacity(pulse ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

/// A compact inline scanning indicator for use inside cards/cells.
struct ScanningPlaceholder: View {
    @ObservedObject private var scan = DiskScanProgress.shared

    var body: some View {
        if scan.isScanning {
            HStack(spacing: 6) {
                ProgressDot()
                Text(scan.currentTask)
                    .font(PareFont.mono(10))
                    .foregroundStyle(PareColor.ink4)
                    .lineLimit(1)
            }
        } else {
            EmptyView()
        }
    }
}
