// App/Sources/Views/Account/SubscriptionView.swift

import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var licence = LicenceManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Subscription").italic().font(PareFont.display(30)).foregroundStyle(PareColor.ink)
                        Text("Manage your Pare licence.").font(PareFont.body(13)).foregroundStyle(PareColor.ink3)
                    }
                    Spacer()
                    Button { coordinator.route = .dashboard } label: {
                        Text("Back").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                .padding(.bottom, 20)
                Divider().padding(.bottom, 22)

                // Current plan hero
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CURRENT PLAN").font(PareFont.mono(11, weight: .medium)).tracking(1).foregroundColor(Color(white: 0.6))
                        HStack(spacing: 6) {
                            Text("Pare").font(PareFont.display(32, weight: .medium)).foregroundColor(.white)
                            Text(licence.isPremium ? "Premium" : "Free").font(PareFont.display(32, weight: .medium)).italic()
                                .foregroundColor(Color(red: 0.420, green: 0.694, blue: 0.549))
                        }
                        if licence.isPremium {
                            Text("Unlimited reclamation \u{00B7} all features unlocked").font(PareFont.body(13)).foregroundColor(Color(white: 0.78))
                        } else {
                            Text("500 MB monthly reclamation cap").font(PareFont.body(13)).foregroundColor(Color(white: 0.78))

                            // Usage meter
                            VStack(alignment: .leading, spacing: 4) {
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.15)).frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.420, green: 0.694, blue: 0.549))
                                        .frame(width: max(1, 200 * licence.usagePercent), height: 6)
                                }
                                .frame(width: 200)
                                Text(licence.usageLabel + " used this month")
                                    .font(PareFont.mono(11)).foregroundColor(Color(white: 0.6))
                            }
                            .padding(.top, 8)
                        }
                    }
                    Spacer()
                    if !licence.isPremium {
                        VStack(alignment: .trailing, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$0").font(PareFont.display(36, weight: .medium)).foregroundColor(.white)
                                Text("/ month").font(PareFont.body(14)).foregroundColor(Color(white: 0.6))
                            }
                        }
                    }
                }
                .padding(28)
                .background(LinearGradient(colors: [Color(red: 0.082, green: 0.078, blue: 0.059), Color(red: 0.165, green: 0.157, blue: 0.137)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 28)

                // Plans
                if !licence.isPremium {
                    Text("Upgrade to Premium").font(PareFont.display(13, weight: .medium)).foregroundStyle(PareColor.ink3)
                        .textCase(.uppercase).tracking(0.6).padding(.bottom, 16)

                    HStack(spacing: 16) {
                        // Premium card
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Premium").font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.ink).padding(.bottom, 4)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$14.99").font(PareFont.display(26, weight: .medium)).foregroundStyle(PareColor.ink)
                                Text("/ year").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                            }.padding(.bottom, 12)
                            VStack(alignment: .leading, spacing: 4) {
                                feature("Unlimited reclamation — no monthly cap")
                                feature("Deep simulator + Xcode cleanup")
                                feature("Scheduled background scans")
                                feature("Cleanup reports (PDF/CSV)")
                            }.padding(.bottom, 18)
                            Spacer()
                            Button { coordinator.route = .settings } label: {
                                Text("Enter licence key")
                                    .font(PareFont.body(14, weight: .medium)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                            Text("Get your key at getpare.lemonsqueezy.com")
                                .font(PareFont.mono(10)).foregroundStyle(PareColor.ink4)
                                .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 8)
                        }
                        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [PareColor.accentSoft, PareColor.surface], startPoint: .top, endPoint: .center))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))
                        .overlay(alignment: .top) {
                            Text("BEST VALUE").font(PareFont.mono(10, weight: .medium)).foregroundStyle(.white).tracking(0.7)
                                .padding(.horizontal, 12).padding(.vertical, 4).background(PareColor.ink).clipShape(Capsule())
                                .offset(y: -10)
                        }

                        // Family card
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Family").font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.ink).padding(.bottom, 4)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$29.99").font(PareFont.display(26, weight: .medium)).foregroundStyle(PareColor.ink)
                                Text("/ year").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                            }.padding(.bottom, 12)
                            VStack(alignment: .leading, spacing: 4) {
                                feature("Everything in Premium")
                                feature("Up to 3 Macs on one licence")
                                feature("Shared family billing")
                                feature("Priority support")
                            }.padding(.bottom, 18)
                            Spacer()
                            Button { coordinator.route = .settings } label: {
                                Text("Enter licence key")
                                    .font(PareFont.body(14, weight: .medium)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                            Text("Get your key at getpare.lemonsqueezy.com")
                                .font(PareFont.mono(10)).foregroundStyle(PareColor.ink4)
                                .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 8)
                        }
                        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(PareColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))
                    }
                } else {
                    // Premium active state
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 24)).foregroundStyle(PareColor.forest)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Premium is active").font(PareFont.body(16, weight: .medium)).foregroundStyle(PareColor.ink)
                                Text("Unlimited cleanup on this Mac. All features unlocked.").font(PareFont.body(13)).foregroundStyle(PareColor.ink3)
                            }
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Licence key").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                                Text(licence.licenceKey).font(PareFont.mono(11)).foregroundStyle(PareColor.ink3)
                            }
                            Spacer()
                            Button("Deactivate") { licence.deactivate() }
                                .font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.danger)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.831, green: 0.690, blue: 0.690), lineWidth: 1)).buttonStyle(.plain)
                        }
                    }
                    .padding(22).background(PareColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                    .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
                }
            }
            .padding(.horizontal, 40).padding(.vertical, 32)
        }
        .background(PareColor.bg)
    }

    private func feature(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text("\u{2713}").font(.system(size: 12, weight: .semibold)).foregroundStyle(PareColor.forest)
            Text(text).font(PareFont.body(13)).foregroundStyle(PareColor.ink2)
        }
    }
}
