// App/Sources/Views/Categories/CategoryDetailView.swift

import SwiftUI

struct CategoryDetailView: View {
    let category: CategoryType
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm: CategoryDetailViewModel

    init(category: CategoryType) {
        self.category = category
        _vm = StateObject(wrappedValue: CategoryDetailViewModel(category: category))
    }

    var body: some View {
        ZStack {
            mainContent

            if vm.showConfirm { confirmModal }
            if vm.showSuccess { successOverlay }
            if vm.showPaywall { PaywallModal(isPresented: $vm.showPaywall) }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Header ───────────────────────────────────
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category.title).italic()
                                .font(PareFont.display(30))
                                .foregroundStyle(PareColor.ink)
                            Text(category.subtitle)
                                .font(PareFont.body(13))
                                .foregroundStyle(PareColor.ink3)
                        }
                        Spacer()
                        Button {
                            coordinator.route = .dashboard
                        } label: {
                            Text("Back")
                                .font(PareFont.body(13, weight: .medium))
                                .foregroundStyle(PareColor.ink2)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 20)
                    Divider().padding(.bottom, 22)

                    // ── Scan progress ────────────────────────────
                    if vm.isLoading {
                        scanProgressView
                            .padding(.bottom, 18)
                    }

                    // ── Summary bar ──────────────────────────────
                    if !vm.summaryCards.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(vm.summaryCards) { card in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(card.label)
                                        .font(PareFont.mono(10, weight: .medium))
                                        .foregroundStyle(PareColor.ink3)
                                        .tracking(0.7)
                                        .textCase(.uppercase)
                                    Text(card.value)
                                        .font(PareFont.display(22, weight: .medium))
                                        .foregroundStyle(card.isAccent ? PareColor.forest : PareColor.ink)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .pareCard()
                            }
                        }
                        .padding(.bottom, 18)
                    }

                    // ── Search ───────────────────────────────────
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(PareColor.ink4)
                        TextField("Search files...", text: $vm.searchQuery)
                            .textFieldStyle(.plain).font(PareFont.body(13))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(PareColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1))
                    .padding(.bottom, 12)

                    // ── Filter pills + selection count ───────────
                    HStack {
                        HStack(spacing: 8) {
                            ForEach(vm.filters, id: \.self) { filter in
                                Button {
                                    vm.activeFilter = filter
                                } label: {
                                    Text(filter)
                                        .font(PareFont.body(12, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(vm.activeFilter == filter ? PareColor.ink : PareColor.surface)
                                        .foregroundStyle(vm.activeFilter == filter ? PareColor.bg : PareColor.ink2)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(vm.activeFilter == filter ? PareColor.ink : PareColor.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Selected:")
                                .font(PareFont.body(12))
                                .foregroundStyle(PareColor.ink3)
                            Text("\(vm.selectedCount)")
                                .font(PareFont.mono(12, weight: .medium))
                                .foregroundStyle(PareColor.ink)
                            Text("\u{00B7} Reclaiming:")
                                .font(PareFont.body(12))
                                .foregroundStyle(PareColor.ink3)
                            Text(vm.selectedSizeLabel)
                                .font(PareFont.mono(12, weight: .medium))
                                .foregroundStyle(PareColor.ink)
                        }
                    }
                    .padding(.bottom, 18)

                    // ── Item table ────────────────────────────────
                    if vm.isLoading {
                        // placeholder while scanning
                        Text("Scanning files...")
                            .font(PareFont.mono(11))
                            .foregroundStyle(PareColor.ink4)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if vm.items.isEmpty {
                        VStack(spacing: 8) {
                            Text("No items found")
                                .font(PareFont.display(18, weight: .medium))
                                .foregroundStyle(PareColor.ink3)
                            Text("Try a different filter or run a Smart Scan first.")
                                .font(PareFont.body(13))
                                .foregroundStyle(PareColor.ink4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .background(PareColor.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                        .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).strokeBorder(PareColor.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    } else {
                        // Table header
                        HStack(spacing: 0) {
                            Color.clear.frame(width: 28)
                            Color.clear.frame(width: 50)
                            Text("ITEM").frame(maxWidth: .infinity, alignment: .leading)
                            Text("TYPE").frame(width: 130, alignment: .leading)
                            Text("LAST TOUCHED").frame(width: 100, alignment: .leading)
                            Text("SIZE").frame(width: 90, alignment: .trailing)
                        }
                        .font(PareFont.mono(10, weight: .medium))
                        .foregroundStyle(PareColor.ink3)
                        .tracking(0.6)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(PareColor.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 2)

                        VStack(spacing: 0) {
                            ForEach(vm.items) { item in
                                ItemRow(item: item) {
                                    vm.toggleItem(item.id)
                                }
                            }
                        }
                        .background(PareColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                        .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)
                .padding(.bottom, 100)
            }

            // ── Sticky footer ────────────────────────────────
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(vm.selectedSizeLabel)
                        .font(PareFont.display(24, weight: .medium))
                        .foregroundStyle(PareColor.ink)
                    Text("will be moved to Recovery Bin")
                        .font(PareFont.body(12))
                        .foregroundStyle(PareColor.ink3)
                }
                Spacer()
                Button { vm.selectAll() } label: {
                    Text("Select all")
                        .font(PareFont.body(13, weight: .medium))
                        .foregroundStyle(PareColor.ink3)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                Button { vm.deselectAll() } label: {
                    Text("Deselect all")
                        .font(PareFont.body(13, weight: .medium))
                        .foregroundStyle(PareColor.ink3)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                Button { vm.reviewAndClean() } label: {
                    Text("Review & Clean")
                        .font(PareFont.body(13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(PareColor.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider() }
        }
        .background(PareColor.bg)
    }

    // MARK: - Scan Progress

    private var scanProgressView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(PareColor.forest)
                    .frame(width: 6, height: 6)
                    .modifier(PulseModifier())
                Text(vm.scanTask)
                    .font(PareFont.mono(10))
                    .foregroundStyle(PareColor.ink3)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(vm.scanProgress * 100))%")
                    .font(PareFont.mono(10, weight: .medium))
                    .foregroundStyle(PareColor.forest)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(PareColor.line)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(PareColor.forest)
                        .frame(width: geo.size.width * vm.scanProgress)
                        .animation(.easeInOut(duration: 0.3), value: vm.scanProgress)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Confirm Modal

    private var confirmModal: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { vm.cancelClean() }

            VStack(alignment: .leading, spacing: 0) {
                Text("Move \(vm.selectedCount) files to Recovery Bin?")
                    .font(PareFont.display(22))
                    .foregroundStyle(PareColor.ink)
                    .padding(.bottom, 10)

                Text("These items will be moved out of your live Mac storage but kept recoverable for 30 days. They are not permanently deleted.")
                    .font(PareFont.body(13))
                    .foregroundStyle(PareColor.ink2)
                    .lineSpacing(3)
                    .padding(.bottom, 16)

                // Detail box
                VStack(spacing: 4) {
                    detailRow("Files affected", "\(vm.selectedCount)")
                    detailRow("Space reclaimed", vm.selectedSizeLabel)
                    detailRow("Recoverable until", recoverableDate)
                }
                .padding(14)
                .background(PareColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1))
                .padding(.bottom, 14)

                // Reassurance
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 12))
                    Text("Nothing leaves your Mac. System and protected paths are excluded.")
                        .font(PareFont.body(12))
                }
                .foregroundStyle(PareColor.forest)
                .padding(12)
                .background(PareColor.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.accentLine, lineWidth: 1))
                .padding(.bottom, 20)

                // Actions
                HStack {
                    Spacer()
                    Button { vm.cancelClean() } label: {
                        Text("Cancel")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { vm.confirmClean() } label: {
                        Text("Move to Bin")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(PareColor.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .frame(maxWidth: 440)
            .background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 40, y: 12)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(PareFont.mono(12))
                .foregroundStyle(PareColor.ink2)
            Spacer()
            Text(value)
                .font(PareFont.mono(12, weight: .medium))
                .foregroundStyle(PareColor.ink)
        }
    }

    private var recoverableDate: String {
        let date = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM yyyy"
        return fmt.string(from: date)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Check mark
                ZStack {
                    Circle()
                        .fill(PareColor.accentSoft)
                        .frame(width: 64, height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(PareColor.forest)
                }

                (Text("You reclaimed ") + Text(CategoryDetailViewModel.fmt(vm.cleanedSize)).italic())
                    .font(PareFont.display(28))
                    .foregroundStyle(PareColor.ink)

                Text("\(vm.cleanedCount) files moved to the Recovery Bin. You can restore them anytime in the next 30 days.")
                    .font(PareFont.body(14))
                    .foregroundStyle(PareColor.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                HStack(spacing: 12) {
                    if LicenceManager.shared.isPremium {
                        Menu {
                            Button("Export as PDF") { CleanupReportGenerator.generate(format: .pdf) }
                            Button("Export as CSV") { CleanupReportGenerator.generate(format: .csv) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 11))
                                Text("Export Report")
                            }
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                        }
                    }

                    Button {
                        coordinator.route = .recovery
                    } label: {
                        Text("View Recovery Bin")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        vm.showSuccess = false
                        coordinator.route = .dashboard
                    } label: {
                        Text("Back to Dashboard")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(PareColor.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
            .background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 40, y: 12)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PareColor.line, lineWidth: 1))
        }
    }
}

// MARK: - Pulse Modifier

private struct PulseModifier: ViewModifier {
    @State private var pulse = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pulse ? 1.3 : 1.0)
            .opacity(pulse ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: CategoryItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Checkbox
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(item.isSelected ? PareColor.ink : PareColor.lineStrong, lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                if item.isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PareColor.ink)
                        .frame(width: 16, height: 16)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PareColor.bg)
                }
            }
            .frame(width: 28)
            .opacity(item.isProtected ? 0.4 : 1)

            // Thumbnail
            Text(item.thumbLabel)
                .font(PareFont.mono(10, weight: .medium))
                .foregroundStyle(PareColor.ink3)
                .textCase(.uppercase)
                .frame(width: 36, height: 36)
                .background(PareColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(PareColor.line, lineWidth: 1))
                .padding(.trailing, 14)

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(PareFont.body(13, weight: .medium))
                    .foregroundStyle(item.isProtected ? PareColor.ink3 : PareColor.ink)
                    .lineLimit(1)
                Text(item.detail)
                    .font(PareFont.mono(11))
                    .foregroundStyle(PareColor.ink4)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Type
            Text(item.typeLabel)
                .font(PareFont.mono(10, weight: .medium))
                .foregroundStyle(PareColor.ink3)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(width: 130, alignment: .leading)

            // Last touched
            Text(item.lastTouched)
                .font(PareFont.mono(10))
                .foregroundStyle(PareColor.ink4)
                .textCase(.uppercase)
                .frame(width: 100, alignment: .leading)

            // Size
            Text(item.sizeLabel)
                .font(PareFont.mono(12, weight: .medium))
                .foregroundStyle(PareColor.ink3)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(item.isProtected ? PareColor.surface2 : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if !item.isProtected { onToggle() }
        }
        .overlay(alignment: .bottom) { Divider() }
    }
}
