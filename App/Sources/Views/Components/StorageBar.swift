// App/Sources/Views/Components/StorageBar.swift

import SwiftUI

struct StorageBarSegment: Identifiable {
    let id = UUID()
    let label: String
    let bytes: Int64
    let color: Color
}

struct StorageBar: View {
    let segments: [StorageBarSegment]
    let totalCapacity: Int64
    var height: CGFloat = 12

    private var usedBytes: Int64 {
        segments.reduce(Int64(0)) { $0 + $1.bytes }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            if width > 0 {
                HStack(spacing: 0) {
                    ForEach(segments) { seg in
                        Rectangle()
                            .fill(seg.color)
                            .frame(width: CGFloat(seg.bytes) / CGFloat(totalCapacity) * width)
                    }
                    Rectangle()
                        .fill(PareColor.line)
                        .frame(maxWidth: .infinity)
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: height)
    }
}
