// App/Sources/Views/Components/Sidebar.swift
//
// Custom sidebar matching the v0.6 prototype: brand mark, user chip,
// grouped navigation with category size badges, sticky Recovery Bin footer.

import SwiftUI
import Combine
import PareKit

struct Sidebar: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = SidebarViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Brand
            BrandHeader()

            // User chip
            UserChip(name: vm.userName)

            ScrollView {
                VStack(spacing: 0) {
                    SidebarSection(label: "WORKSPACE") {
                        SidebarNavItem(icon: "square.grid.2x2", title: "Dashboard", route: .dashboard)
                        SidebarNavItem(icon: "rectangle.split.3x3", title: "Space Lens", route: .spaceLens)
                        SidebarNavItem(icon: "chart.line.uptrend.xyaxis", title: "Insights", route: .insights)
                    }

                    SidebarSection(label: "CATEGORIES") {
                        CategoryNavItem(icon: "desktopcomputer", title: "System Junk", size: vm.systemJunkSize, route: .systemJunk)
                        CategoryNavItem(icon: "doc.on.doc", title: "Duplicates", size: vm.duplicatesSize, route: .duplicates)
                        CategoryNavItem(icon: "arrow.up.doc", title: "Large Files", size: vm.largeFilesSize, route: .largeFiles)
                        CategoryNavItem(icon: "square.and.arrow.down", title: "Uninstaller", size: vm.uninstallerSize, route: .uninstaller)
                        CategoryNavItem(icon: "envelope", title: "Mail Cleanup", size: vm.mailSize, route: .mailCleanup)
                        CategoryNavItem(icon: "chevron.left.forwardslash.chevron.right", title: "Developer Junk", size: vm.developerSize, route: .developerJunk)
                        CategoryNavItem(icon: "arrow.down.circle", title: "Downloads", size: vm.downloadsSize, route: .downloads)
                        CategoryNavItem(icon: "photo.on.rectangle", title: "Photos", size: vm.photosSize, route: .photos)
                        SidebarNavItem(icon: "globe", title: "Browser Cleanup", route: .browserCleanup)
                        SidebarNavItem(icon: "icloud", title: "iCloud Storage", route: .iCloudStorage)
                        SidebarNavItem(icon: "bolt.fill", title: "Startup Items", route: .startupItems)
                    }

                    SidebarSection(label: "ACCOUNT") {
                        SidebarNavItem(icon: "person.circle", title: "Profile", route: .profile)
                        SidebarNavItem(icon: "creditcard", title: "Subscription", route: .subscription)
                        SidebarNavItem(icon: "gearshape", title: "Settings", route: .settings)
                        SidebarNavItem(icon: "questionmark.circle", title: "Help", route: .help)
                    }
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)

            // Sticky footer
            RecoveryBinFooter()
        }
        .padding(.horizontal, 10)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(minWidth: 240, maxWidth: 240)
        .background(PareColor.surface2)
    }
}

// MARK: - Sidebar ViewModel

private final class SidebarViewModel: ObservableObject {
    @Published var userName: String = "User"
    @Published var systemJunkSize: String = "..."
    @Published var duplicatesSize: String = "scan"
    @Published var largeFilesSize: String = "scan"
    @Published var downloadsSize: String = "..."
    @Published var photosSize: String = "..."
    @Published var uninstallerSize: String = "scan"
    @Published var mailSize: String = "..."
    @Published var developerSize: String = "..."

    private var cancellable: AnyCancellable?

    init() {
        userName = NSFullUserName().components(separatedBy: " ").first ?? "User"
        loadSizes()

        // Refresh when items are cleaned
        cancellable = CleanedItemStore.shared.objectWillChange
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadSizes()
            }
    }

    private func loadSizes() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sizes = SystemStorageProvider.categorySizes()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.systemJunkSize = Self.fmt(sizes.systemJunk)
                self.duplicatesSize = sizes.duplicates > 0 ? Self.fmt(sizes.duplicates) : "scan"
                self.largeFilesSize = sizes.largeFiles > 0 ? Self.fmt(sizes.largeFiles) : "scan"
                self.downloadsSize  = Self.fmt(sizes.downloads)
                self.photosSize     = Self.fmt(sizes.photos)
                self.uninstallerSize = sizes.uninstaller > 0 ? Self.fmt(sizes.uninstaller) : "scan"
                self.mailSize       = Self.fmt(sizes.mail)
                self.developerSize  = Self.fmt(sizes.developer)
            }
        }
    }

    private static func fmt(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Brand Header

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7)
                .fill(PareColor.ink)
                .frame(width: 26, height: 26)
                .overlay(
                    Text("P")
                        .font(PareFont.display(14, weight: .medium))
                        .foregroundStyle(PareColor.bg)
                )
            Text("Pare")
                .font(PareFont.display(14, weight: .medium))
                .foregroundStyle(PareColor.ink)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - User Chip

private struct UserChip: View {
    let name: String
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var licence = LicenceManager.shared
    @State private var isHovered = false

    private var tierLabel: String {
        switch licence.tier {
        case .free:      return "FREE \u{00B7} \(licence.usageLabel)"
        case .premium:   return "PREMIUM"
        case .family:    return "FAMILY"
        case .lifetime:  return "LIFETIME"
        case .education: return "EDUCATION"
        }
    }

    private var tierColor: Color {
        licence.isPremium ? PareColor.forest : PareColor.ink3
    }

    var body: some View {
        Button { coordinator.route = .profile } label: {
        HStack(spacing: 10) {
            Circle()
                .fill(LinearGradient(colors: [PareColor.forest, CategoryColor.apps],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(PareFont.display(13, weight: .medium))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(PareFont.body(12, weight: .medium))
                    .foregroundStyle(PareColor.ink)
                    .lineLimit(1)
                Text(tierLabel)
                    .font(PareFont.mono(10))
                    .foregroundStyle(tierColor)
                    .lineLimit(1)
            }

            Spacer()

            Text("\u{203A}")
                .font(.system(size: 14))
                .foregroundStyle(PareColor.ink4)
        }
        .padding(10)
        .background(PareColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
        .overlay(
            RoundedRectangle(cornerRadius: PareRadius.standard)
                .stroke(isHovered ? PareColor.lineStrong : PareColor.line, lineWidth: 1)
        )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.bottom, 16)
    }
}

// MARK: - Section

private struct SidebarSection<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PareFont.mono(10, weight: .medium))
                .foregroundStyle(PareColor.ink3)
                .tracking(0.8)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)

            content()
        }
    }
}

// MARK: - Nav Item

private struct SidebarNavItem: View {
    @EnvironmentObject var coordinator: AppCoordinator
    let icon: String
    let title: String
    let route: AppCoordinator.Route
    @State private var isHovered = false

    private var isActive: Bool { coordinator.route == route }

    var body: some View {
        Button {
            coordinator.show(route)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isActive ? PareColor.forest : PareColor.ink3)
                    .frame(width: 16)
                Text(title)
                    .font(PareFont.body(13, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? PareColor.ink : PareColor.ink2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? PareColor.surface : (isHovered ? PareColor.ink.opacity(0.04) : Color.clear))
            )
            .pareShadow(isActive ? .small : .small)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Category Nav Item

private struct CategoryNavItem: View {
    let icon: String
    let title: String
    let size: String
    let route: AppCoordinator.Route
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var isHovered = false

    private var isActive: Bool { coordinator.route == route }

    var body: some View {
        Button {
            coordinator.route = route
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isActive ? PareColor.forest : PareColor.ink3)
                    .frame(width: 16)
                Text(title)
                    .font(PareFont.body(13, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? PareColor.ink : PareColor.ink2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text(size)
                    .font(PareFont.mono(10))
                    .foregroundStyle(PareColor.ink4)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? PareColor.surface : (isHovered ? PareColor.ink.opacity(0.04) : Color.clear))
            )
            .pareShadow(isActive ? .small : .small)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Recovery Bin Footer

private struct RecoveryBinFooter: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var store = CleanedItemStore.shared
    @State private var isHovered = false

    var body: some View {
        Button {
            coordinator.route = .recovery
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash.slash")
                    .font(.system(size: 16))
                    .foregroundStyle(PareColor.ink3)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Recovery Bin")
                        .font(PareFont.body(12, weight: .medium))
                        .foregroundStyle(PareColor.ink)
                    Text("\(store.totalCount) items \u{00B7} \(store.daysLabel)")
                        .font(PareFont.mono(10))
                        .foregroundStyle(PareColor.ink3)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
            .overlay(
                RoundedRectangle(cornerRadius: PareRadius.standard)
                    .stroke(isHovered ? PareColor.lineStrong : PareColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.top, 8)
    }
}
