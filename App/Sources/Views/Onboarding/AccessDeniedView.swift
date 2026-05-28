// App/Sources/Views/Onboarding/AccessDeniedView.swift
//
// Shown when the user navigates to Smart Scan without Full Disk Access.
// Offers to open System Settings or continue in limited mode.

import SwiftUI

struct AccessDeniedView: View {
    @ObservedObject var permissionManager: PermissionManager
    let onContinueLimited: () -> Void
    let onGranted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Warning icon
                Circle()
                    .fill(PareColor.warningSoft)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(PareColor.warning)
                    )
                    .overlay(
                        Circle().stroke(PareColor.warning.opacity(0.3), lineWidth: 1)
                    )

                (Text("Pare needs ") + Text("Full Disk Access").italic())
                    .font(PareFont.display(28))
                    .foregroundStyle(PareColor.ink)

                Text("Without it, Pare can only scan caches and System Junk \u{2014} about 8 GB of the typical 48 GB reclaimable. Grant access in System Settings to scan your full library, duplicates, mail attachments, and developer artefacts.")
                    .font(PareFont.body(14))
                    .foregroundStyle(PareColor.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 520)

                // Instructions
                VStack(alignment: .leading, spacing: 0) {
                    DeniedStep(number: "1", text: "Click ", bold: "Open System Settings", suffix: " below.")
                    DeniedStep(number: "2", text: "Navigate to ", bold: "Privacy & Security \u{2192} Full Disk Access", suffix: ".")
                    DeniedStep(number: "3", text: "Toggle ", bold: "Pare", suffix: " on. We\u{2019}ll detect it and continue.")
                }
                .padding(20)
                .background(PareColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                .overlay(
                    RoundedRectangle(cornerRadius: PareRadius.standard)
                        .stroke(PareColor.line, lineWidth: 1)
                )
                .frame(maxWidth: 480)

                // Actions
                HStack(spacing: 12) {
                    Button(action: onContinueLimited) {
                        Text("Continue in Limited Mode")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(PareColor.lineStrong, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        permissionManager.openSystemSettings()
                    } label: {
                        Text("Open System Settings")
                            .font(PareFont.body(14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(PareColor.forest)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PareColor.bg)
        .onChange(of: permissionManager.hasFullDiskAccess) { granted in
            if granted { onGranted() }
        }
    }
}

private struct DeniedStep: View {
    let number: String
    let text: String
    let bold: String
    let suffix: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number + ".")
                .font(PareFont.body(13, weight: .medium))
                .foregroundStyle(PareColor.ink2)
                .frame(width: 16)
            (Text(text).foregroundColor(PareColor.ink2) +
             Text(bold).bold().foregroundColor(PareColor.ink) +
             Text(suffix).foregroundColor(PareColor.ink2))
                .font(PareFont.body(13))
                .lineSpacing(3)
        }
        .padding(.vertical, 6)
    }
}
