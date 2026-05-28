// App/Sources/Views/Onboarding/ChoosePlanView.swift

import SwiftUI

struct ChoosePlanView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedPlan = "free"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 6) {
                    dot(false); dot(true); dot(false); dot(false)
                }
                .padding(.bottom, 22)

                Text("Pick a plan to start")
                    .font(PareFont.display(32))
                    .foregroundStyle(PareColor.ink)
                    .padding(.bottom, 8)

                Text("You can start free and upgrade anytime. No payment method needed for the Free tier.")
                    .font(PareFont.body(14))
                    .foregroundStyle(PareColor.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                // Plan cards
                HStack(alignment: .top, spacing: 14) {
                    planCard(id: "free", name: "Free",
                             desc: "Try Pare without committing. Great for occasional cleanups.",
                             price: "\u{20A6}0", period: "/ month", alt: "No payment method required",
                             features: ["500 MB monthly reclamation cap", "All scanners (except deep simulator)", "30-day Recovery Bin", "1 Mac"],
                             isFeatured: false)

                    planCard(id: "premium", name: "Premium",
                             desc: "For developers, creators, and anyone with a Mac that\u{2019}s always full.",
                             price: "\u{20A6}9,500", period: "/ year", alt: "\u{2248} $14.99 or \u{00A3}11.99 \u{00B7} billed annually",
                             features: ["Unlimited reclamation", "Deep simulator + Xcode cleanup", "Scheduled background scans", "Cleanup reports (PDF/CSV)", "1 Mac \u{00B7} upgradeable to Family"],
                             isFeatured: true)

                    planCard(id: "family", name: "Family",
                             desc: "For households, partners, and small teams sharing devices.",
                             price: "\u{20A6}18,500", period: "/ year", alt: "\u{2248} $29.99 or \u{00A3}23.99 \u{00B7} billed annually",
                             features: ["Everything in Premium", "Up to 3 Macs on one licence", "Shared family billing", "Priority support"],
                             isFeatured: false)
                }
                .padding(.bottom, 28)

                // Actions
                HStack(spacing: 10) {
                    Button { coordinator.onboardingStep = .welcome } label: {
                        Text("Back").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }.buttonStyle(.plain)

                    Button { coordinator.advanceOnboarding() } label: {
                        Text("Continue with selected plan")
                            .font(PareFont.body(14, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
                .padding(.bottom, 12)

                Button { coordinator.advanceOnboarding() } label: {
                    Text("Skip \u{2014} start free, decide later")
                        .font(PareFont.body(12, weight: .medium)).foregroundStyle(PareColor.ink)
                }.buttonStyle(.plain)
            }
            .frame(maxWidth: 920)
            .padding(.horizontal, 40).padding(.vertical, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PareColor.bg)
    }

    private func dot(_ active: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(active ? PareColor.ink : PareColor.line)
            .frame(width: 24, height: 3)
    }

    private func planCard(id: String, name: String, desc: String, price: String, period: String, alt: String, features: [String], isFeatured: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name).font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.ink).padding(.bottom, 4)
            Text(desc).font(PareFont.body(12)).foregroundStyle(PareColor.ink3).lineSpacing(3).frame(minHeight: 32, alignment: .top).padding(.bottom, 18)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(price).font(PareFont.display(30, weight: .medium)).foregroundStyle(PareColor.ink)
                Text(period).font(PareFont.body(13)).foregroundStyle(PareColor.ink3)
            }
            .padding(.bottom, 4)

            Text(alt).font(PareFont.mono(11)).foregroundStyle(PareColor.ink3).padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(features, id: \.self) { f in
                    HStack(spacing: 4) {
                        Text("\u{2713}").foregroundStyle(PareColor.forest).font(.system(size: 12, weight: .semibold))
                        Text(f).font(PareFont.body(13)).foregroundStyle(PareColor.ink2)
                    }
                }
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isFeatured ? LinearGradient(colors: [PareColor.accentSoft, PareColor.surface], startPoint: .top, endPoint: .center) : LinearGradient(colors: [PareColor.surface, PareColor.surface], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selectedPlan == id ? PareColor.ink : PareColor.line, lineWidth: selectedPlan == id ? 2 : 1))
        .overlay(alignment: .top) {
            if isFeatured {
                Text("BEST VALUE").font(PareFont.mono(10, weight: .medium)).foregroundStyle(.white).tracking(0.7)
                    .padding(.horizontal, 12).padding(.vertical, 4).background(PareColor.ink).clipShape(Capsule())
                    .offset(y: -10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedPlan = id }
    }
}
