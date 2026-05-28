// App/Sources/Views/Components/FDABannerView.swift
//
// Dismissable banner shown on Dashboard when Full Disk Access is not granted.
// Matches prototype: limited-banner with warning styling.

import SwiftUI

struct FDABannerView: View {
    @ObservedObject private var permissions = PermissionManager.shared
    @State private var dismissed = false

    var body: some View {
        if !dismissed {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16))
                    .foregroundStyle(PareColor.warning)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 0) {
                        Text("Limited mode. ").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                        Text("Pare doesn\u{2019}t have Full Disk Access yet.").font(PareFont.body(13)).foregroundStyle(PareColor.ink2)
                    }
                    Text("Some protected directories can\u{2019}t be scanned. Grant access for a complete cleanup.")
                        .font(PareFont.body(13)).foregroundStyle(PareColor.ink2)
                }
                .lineSpacing(2)

                Spacer()

                Button {
                    permissions.openSystemSettings()
                } label: {
                    Text("Grant Access")
                        .font(PareFont.body(12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PareColor.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button { dismissed = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(PareColor.ink3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(PareColor.warningSoft)
            .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(Color(red: 0.894, green: 0.784, blue: 0.588), lineWidth: 1))
        }
    }
}
