// App/Sources/Views/Components/PaywallModal.swift
//
// Shown when user tries to clean beyond 500 MB free cap.
// CleanMyMac-style: "You've reached your free limit, enter a licence key to continue."

import SwiftUI

struct PaywallModal: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var licence = LicenceManager.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle().fill(PareColor.warningSoft).frame(width: 64, height: 64)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(PareColor.warning)
                }
                .padding(.bottom, 20)

                Text("Free limit reached")
                    .font(PareFont.display(24, weight: .medium))
                    .foregroundStyle(PareColor.ink)
                    .padding(.bottom, 8)

                Text("You\u{2019}ve used \(licence.usageLabel) of your 500 MB monthly free cleanup cap. Enter a licence key to unlock unlimited reclamation.")
                    .font(PareFont.body(14))
                    .foregroundStyle(PareColor.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 360)
                    .padding(.bottom, 24)

                // Usage bar
                VStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(PareColor.line).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(PareColor.warning)
                            .frame(width: max(1, 300 * licence.usagePercent), height: 8)
                    }
                    .frame(width: 300)
                    Text(licence.usageLabel)
                        .font(PareFont.mono(11)).foregroundStyle(PareColor.warning)
                }
                .padding(.bottom, 24)

                // What you get
                VStack(alignment: .leading, spacing: 8) {
                    upgradePoint("Unlimited cleanup \u{2014} no monthly cap")
                    upgradePoint("Deep simulator + Xcode cleanup")
                    upgradePoint("Scheduled background scans")
                    upgradePoint("Cleanup reports (PDF/CSV)")
                }
                .padding(16)
                .background(PareColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1))
                .padding(.bottom, 24)

                // Actions
                VStack(spacing: 10) {
                    Button {
                        isPresented = false
                        coordinator.route = .settings
                    } label: {
                        Text("Enter licence key")
                            .font(PareFont.body(14, weight: .medium)).foregroundStyle(.white)
                            .frame(width: 280).padding(.vertical, 12)
                            .background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        isPresented = false
                        coordinator.route = .subscription
                    } label: {
                        Text("Get a licence key from pare.app")
                            .font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.forest)
                    }
                    .buttonStyle(.plain)

                    Button { isPresented = false } label: {
                        Text("Maybe later")
                            .font(PareFont.body(13)).foregroundStyle(PareColor.ink4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
            .frame(maxWidth: 460)
            .background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 40, y: 12)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))
        }
    }

    private func upgradePoint(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(PareColor.forest)
            Text(text).font(PareFont.body(13)).foregroundStyle(PareColor.ink2)
        }
    }
}
