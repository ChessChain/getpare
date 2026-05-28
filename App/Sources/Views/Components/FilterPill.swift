// App/Sources/Views/Components/FilterPill.swift

import SwiftUI

struct FilterPill: View {
    let label: String
    let isActive: Bool
    var count: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                if let count = count {
                    Text("(\(count))")
                        .foregroundStyle(isActive ? PareColor.bg.opacity(0.7) : PareColor.ink4)
                }
            }
            .font(PareFont.body(12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? PareColor.ink : PareColor.surface)
            .foregroundStyle(isActive ? PareColor.bg : PareColor.ink2)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isActive ? Color.clear : PareColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
