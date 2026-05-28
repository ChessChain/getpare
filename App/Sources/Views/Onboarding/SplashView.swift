// App/Sources/Views/Onboarding/SplashView.swift
//
// CleanMyMac-style: no auth gate. App works immediately.
// Splash → Welcome → Choose Plan → Permission → Dashboard

import SwiftUI

struct SplashView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            Text("P")
                .font(PareFont.display(44, weight: .medium))
                .foregroundStyle(PareColor.bg)
                .frame(width: 84, height: 84)
                .background(PareColor.ink)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.18), radius: 30, y: 10)
                .padding(.bottom, 28)

            (Text("Reclaim your ") + Text("Mac").italic() + Text("."))
                .font(PareFont.display(44))
                .tracking(-1.5)
                .foregroundStyle(PareColor.ink)
                .multilineTextAlignment(.center)
                .padding(.bottom, 14)

            Text("A privacy-first storage cleanup app for macOS.\nOn-device. Reversible. Built for creators, developers, and students.")
                .font(PareFont.body(16))
                .foregroundStyle(PareColor.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 420)
                .padding(.bottom, 36)

            // Primary CTA — no auth, straight to app
            Button { coordinator.onboardingStep = .welcome } label: {
                Text("Get Started")
                    .font(PareFont.body(14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 320).padding(.vertical, 12)
                    .background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)

            // Already have a licence key
            Button {
                // Skip onboarding, go to dashboard, user enters key in Settings
                coordinator.completeOnboarding()
            } label: {
                Text("I have a licence key")
                    .font(PareFont.body(14, weight: .medium))
                    .foregroundStyle(PareColor.ink2)
                    .frame(width: 320).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 4) {
                Text("Free to use \u{00B7} 500 MB/month cleanup cap \u{00B7} No account required")
                    .font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                Text("Upgrade anytime with a licence key from pare.app")
                    .font(PareFont.body(12)).foregroundStyle(PareColor.ink4)
                Text("Made by ClearPath Digital \u{00B7} Pare v1.0")
                    .font(PareFont.mono(11)).foregroundStyle(PareColor.ink4).padding(.top, 8)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PareColor.bg)
    }
}
