// App/Sources/Views/Onboarding/WelcomeView.swift
//
// Onboarding step 1: privacy explainer with three promise points.

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Brand mark
                RoundedRectangle(cornerRadius: 14)
                    .fill(PareColor.forest)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text("P")
                            .font(PareFont.display(28, weight: .medium))
                            .foregroundStyle(.white)
                    )

                // Headline
                (Text("Welcome to ") + Text("Pare").italic())
                    .font(PareFont.display(28))
                    .foregroundStyle(PareColor.ink)

                Text("A calmer way to reclaim disk space on your Mac. Pare scans, you decide, and anything removed is recoverable for 30 days.")
                    .font(PareFont.body(14))
                    .foregroundStyle(PareColor.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)

                // Step indicators
                OnboardingStepDots(current: 0, total: 4)

                // Promise points
                VStack(spacing: 0) {
                    PromisePoint(text: "Everything stays on your Mac.", detail: "Pare runs entirely on-device. No file names, paths, or contents ever leave.")
                    PromisePoint(text: "You approve every deletion.", detail: "Pare previews exactly what\u{2019}s selected before anything moves.")
                    PromisePoint(text: "30-day Recovery Bin.", detail: "Anything Pare removes can be restored with a single click for a month.")
                }
                .background(PareColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                .overlay(
                    RoundedRectangle(cornerRadius: PareRadius.standard)
                        .stroke(PareColor.line, lineWidth: 1)
                )
                .frame(maxWidth: 480)

                // FDA prompt
                if !PermissionManager.shared.hasFullDiskAccess {
                    HStack(spacing: 14) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 20))
                            .foregroundStyle(PareColor.forest)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Grant Full Disk Access for best results")
                                .font(PareFont.body(13, weight: .medium))
                                .foregroundStyle(PareColor.ink)
                            Text("Pare works without it, but can\u{2019}t scan Mail, protected caches, or developer artefacts.")
                                .font(PareFont.body(12))
                                .foregroundStyle(PareColor.ink3)
                                .lineSpacing(2)
                        }
                        Spacer()
                        Button {
                            PermissionManager.shared.openSystemSettings()
                        } label: {
                            Text("Open Settings")
                                .font(PareFont.body(12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(PareColor.forest)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(PareColor.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                    .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.accentLine, lineWidth: 1))
                    .frame(maxWidth: 480)
                }

                // Continue button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(PareFont.body(14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(PareColor.forest)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Text("Made by ClearPath Digital \u{00B7} Pare v1.0")
                    .font(PareFont.mono(11))
                    .foregroundStyle(PareColor.ink4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PareColor.bg)
    }
}

// MARK: - Promise Point

private struct PromisePoint: View {
    let text: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PareColor.forest)
                .frame(width: 20, height: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(PareFont.body(13, weight: .medium))
                    .foregroundStyle(PareColor.ink)
                Text(detail)
                    .font(PareFont.body(13))
                    .foregroundStyle(PareColor.ink2)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 52)
        }
    }
}

// MARK: - Step Dots

struct OnboardingStepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? PareColor.ink : PareColor.line)
                    .frame(width: i == current ? 20 : 8, height: 8)
            }
        }
    }
}
