// App/Sources/Views/Account/HelpView.swift

import SwiftUI

struct HelpView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        (Text("Help ") + Text("& FAQ").italic())
                            .font(PareFont.display(30)).foregroundStyle(PareColor.ink)
                        Text("Common questions about how Pare works.")
                            .font(PareFont.body(13)).foregroundStyle(PareColor.ink3)
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

                // FAQ grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    faqCard("Will Pare delete something important?",
                            "No \u{2014} Pare never permanently deletes on its own. Everything you confirm goes to a sandboxed 30-day Recovery Bin first. Protected system paths are excluded at the engine level.")
                    faqCard("Why does Pare need Full Disk Access?",
                            "Without it, macOS hides most of the locations where reclaimable space accumulates \u{2014} Mail attachments, Library caches, developer artefacts. You can still use Pare in Limited Mode.")
                    faqCard("Does any of my data leave my Mac?",
                            "No. Pare runs entirely on-device. The only network call is a periodic licence check. Anonymous telemetry is off by default; you can opt in under Settings \u{2192} Privacy.")
                    faqCard("How do I restore something I removed?",
                            "Click Recovery Bin in the sidebar, find the item, and hit Restore. The file returns to its original path. After 30 days it\u{2019}s permanently removed.")
                    faqCard("What\u{2019}s the free vs. Premium difference?",
                            "The free tier reclaims up to 500 MB per calendar month. Premium removes the cap and unlocks deep Developer Junk cleanup. From $14.99/year.")
                    faqCard("Can I run Pare from the command line?",
                            "Not in v1.0. A `pare` CLI is on the v1.1 roadmap and will use the same helper, so scans and cleanups from the terminal stay in sync with the app.")
                }
                .padding(.bottom, 32)

                // Keyboard shortcuts
                Text("Keyboard shortcuts").font(PareFont.display(13, weight: .medium)).foregroundStyle(PareColor.ink3)
                    .textCase(.uppercase).tracking(0.6).padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Pare is fully keyboard-navigable. Tab moves through controls, Enter/Space activates, Esc closes modals.")
                        .font(PareFont.body(13)).foregroundStyle(PareColor.ink3).padding(.bottom, 14)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], spacing: 0) {
                        kbdRow("Run Smart Scan", "\u{2318}R")
                        kbdRow("Open Pare from menu bar", "\u{2318}O")
                        kbdRow("Open Settings", "\u{2318},")
                        kbdRow("Switch to Dashboard", "\u{2318}1")
                        kbdRow("Switch to Smart Scan", "\u{2318}2")
                        kbdRow("Switch to Recovery Bin", "\u{2318}3")
                        kbdRow("Show Insights / Trends", "\u{2318}I")
                        kbdRow("Close modal or panel", "Esc")
                        kbdRow("Activate focused control", "Enter / Space")
                        kbdRow("Quit Pare", "\u{2318}Q")
                    }

                    Text("Pare meets WCAG 2.2 AA: every interactive control is reachable via the keyboard with visible focus indicators.")
                        .font(PareFont.body(12)).foregroundStyle(PareColor.ink3).padding(.top, 16)
                }
                .padding(22)
                .background(PareColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
            }
            .padding(.horizontal, 40).padding(.vertical, 32)
        }
        .background(PareColor.bg)
    }

    private func faqCard(_ question: String, _ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question).font(PareFont.display(16, weight: .medium)).foregroundStyle(PareColor.ink)
            Text(answer).font(PareFont.body(13)).foregroundStyle(PareColor.ink2).lineSpacing(3)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PareColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
    }

    private func kbdRow(_ label: String, _ keys: String) -> some View {
        HStack {
            Text(label).font(PareFont.body(13)).foregroundStyle(PareColor.ink2)
            Spacer()
            Text(keys).font(PareFont.mono(12)).foregroundStyle(PareColor.ink)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(PareColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(PareColor.lineStrong, lineWidth: 1))
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }
}
