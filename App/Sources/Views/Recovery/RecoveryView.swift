// App/Sources/Views/Recovery/RecoveryView.swift

import SwiftUI
import PareKit

struct RecoveryView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = RecoveryViewModel()
    @ObservedObject private var store = CleanedItemStore.shared
    @State private var showEmptyConfirm = false
    @State private var emptyConfirmText = ""

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        (Text("Recovery ") + Text("Bin").italic())
                            .font(PareFont.display(30))
                            .foregroundStyle(PareColor.ink)
                        Text("Items here are recoverable for 30 days. After that, Pare permanently removes them.")
                            .font(PareFont.body(13))
                            .foregroundStyle(PareColor.ink3)
                    }
                    Spacer()
                    if !store.items.isEmpty {
                        Button {
                            emptyConfirmText = ""
                            showEmptyConfirm = true
                        } label: {
                            Text("Empty Bin\u{2026}")
                                .font(PareFont.body(13, weight: .medium))
                                .foregroundStyle(PareColor.danger)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.831, green: 0.690, blue: 0.690), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Button { coordinator.route = .dashboard } label: {
                        Text("Back")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 40).padding(.bottom, 16)

                // Toolbar
                HStack {
                    HStack(spacing: 8) {
                        ForEach(RecoveryViewModel.RecoveryFilter.allCases) { filter in
                            Button {
                                vm.selectedFilter = filter
                            } label: {
                                Text(filter == .all ? "\(filter.displayName) (\(store.totalCount))" : filter.displayName)
                                    .font(PareFont.body(12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(vm.selectedFilter == filter ? PareColor.ink : PareColor.surface)
                                    .foregroundStyle(vm.selectedFilter == filter ? PareColor.bg : PareColor.ink2)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(vm.selectedFilter == filter ? PareColor.ink : PareColor.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Bin size:")
                            .font(PareFont.body(12))
                            .foregroundStyle(PareColor.ink3)
                        Text(store.totalSizeLabel)
                            .font(PareFont.mono(12, weight: .medium))
                            .foregroundStyle(PareColor.ink)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 18)

                // Table or empty state
                if vm.filteredItems.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 28))
                            .foregroundStyle(PareColor.ink4)
                        Text("Your Recovery Bin is empty.")
                            .font(PareFont.display(18, weight: .medium))
                            .foregroundStyle(PareColor.ink3)
                        Text("Items you clean will appear here for 30 days.")
                            .font(PareFont.body(13))
                            .foregroundStyle(PareColor.ink4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .background(PareColor.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                    .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).strokeBorder(PareColor.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .padding(.horizontal, 40)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Table header
                            HStack(spacing: 0) {
                                Text("FILE").frame(maxWidth: .infinity, alignment: .leading)
                                Text("CATEGORY").frame(width: 120, alignment: .leading)
                                Text("RESTORABLE").frame(width: 100, alignment: .leading)
                                Text("").frame(width: 160)
                            }
                            .font(PareFont.mono(10, weight: .medium))
                            .foregroundStyle(PareColor.ink3)
                            .tracking(0.6)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(PareColor.surface2)

                            ForEach(vm.filteredItems) { item in
                                RecoveryRow(item: item, onRestore: {
                                    store.restore(id: item.id)
                                }, onDelete: {
                                    store.permanentlyDelete(id: item.id)
                                })
                            }
                        }
                        .background(PareColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                        .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
                        .padding(.horizontal, 40)
                    }
                    Spacer()
                }
            }
            .background(PareColor.bg)

            // Empty Bin confirmation modal
            if showEmptyConfirm {
                emptyBinModal
            }
        }
    }

    // MARK: - Empty Bin Modal (typed confirmation)

    private var emptyBinModal: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { showEmptyConfirm = false }

            VStack(alignment: .leading, spacing: 0) {
                Text("Permanently empty Recovery Bin?")
                    .font(PareFont.display(22))
                    .foregroundStyle(PareColor.ink)
                    .padding(.bottom, 10)

                Text("This removes **\(store.totalCount) items (\(store.totalSizeLabel))** from your Recovery Bin. After this, the files cannot be restored from Pare.")
                    .font(PareFont.body(13))
                    .foregroundStyle(PareColor.ink2)
                    .lineSpacing(3)
                    .padding(.bottom, 16)

                // Detail box
                VStack(spacing: 4) {
                    detailRow("Items affected", "\(store.totalCount)")
                    detailRow("Space cleared", store.totalSizeLabel)
                    detailRow("Action", "Permanent")
                }
                .padding(14)
                .background(PareColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1))
                .padding(.bottom, 14)

                // Typed confirmation
                Text("Type **empty** below to confirm.")
                    .font(PareFont.body(12))
                    .foregroundStyle(PareColor.ink2)
                    .padding(.bottom, 6)

                TextField("empty", text: $emptyConfirmText)
                    .textFieldStyle(.plain)
                    .font(PareFont.mono(13))
                    .padding(10)
                    .background(PareColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    .padding(.bottom, 14)

                // Warning
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                    Text("This step cannot be undone.")
                        .font(PareFont.body(12))
                }
                .foregroundStyle(PareColor.warning)
                .padding(12)
                .background(PareColor.warningSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.894, green: 0.784, blue: 0.588), lineWidth: 1))
                .padding(.bottom, 20)

                // Actions
                HStack {
                    Spacer()
                    Button { showEmptyConfirm = false } label: {
                        Text("Cancel")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(PareColor.ink2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.removeAll()
                        showEmptyConfirm = false
                    } label: {
                        Text("Empty Recovery Bin")
                            .font(PareFont.body(13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(emptyConfirmText.lowercased().trimmingCharacters(in: .whitespaces) == "empty" ? PareColor.ink : PareColor.ink.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(emptyConfirmText.lowercased().trimmingCharacters(in: .whitespaces) != "empty")
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
            Text(label).font(PareFont.mono(12)).foregroundStyle(PareColor.ink2)
            Spacer()
            Text(value).font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink)
        }
    }
}

// MARK: - Recovery Row

private struct RecoveryRow: View {
    let item: CleanedItemStore.CleanedItem
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // File info
            HStack(spacing: 10) {
                Image(systemName: iconForCategory(item.category))
                    .font(.system(size: 16))
                    .foregroundStyle(PareColor.ink3)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(PareFont.body(13))
                        .foregroundStyle(PareColor.ink)
                        .lineLimit(1)
                    Text(item.metaLabel)
                        .font(PareFont.mono(11))
                        .foregroundStyle(PareColor.ink3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Category
            Text(item.category.uppercased())
                .font(PareFont.mono(10))
                .foregroundStyle(PareColor.ink3)
                .tracking(0.5)
                .frame(width: 120, alignment: .leading)

            // Days left
            Text("\(item.daysLeft) days left")
                .font(PareFont.mono(12))
                .foregroundStyle(PareColor.warning)
                .frame(width: 100, alignment: .leading)

            // Restore button
            Button { onRestore() } label: {
                Text("RESTORE")
                    .font(PareFont.mono(11, weight: .medium))
                    .foregroundStyle(PareColor.ink2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(PareColor.lineStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Delete button
            Button { onDelete() } label: {
                Text("DELETE")
                    .font(PareFont.mono(11, weight: .medium))
                    .foregroundStyle(PareColor.danger)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.831, green: 0.690, blue: 0.690), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 20)
        }
    }

    private func iconForCategory(_ cat: String) -> String {
        switch cat {
        case "System Junk":       return "desktopcomputer"
        case "Developer Junk":    return "hammer"
        case "Downloads":         return "arrow.down.circle"
        case "Mail Cleanup":      return "envelope"
        case "Large & Old Files": return "doc.badge.arrow.up"
        case "Duplicates":        return "doc.on.doc"
        case "Uninstaller":       return "trash"
        default:                  return "doc"
        }
    }
}
