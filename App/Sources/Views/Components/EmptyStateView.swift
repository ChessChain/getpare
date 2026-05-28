// App/Sources/Views/Components/EmptyStateView.swift

import SwiftUI

struct EmptyStateView: View {
    var icon: String = "sparkles"
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(PareColor.ink3)
            Text(message)
                .font(PareFont.body(13))
                .foregroundStyle(PareColor.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .background(PareColor.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: PareRadius.standard)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(PareColor.lineStrong)
        )
        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
    }
}
