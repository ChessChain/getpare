// App/Sources/Views/Categories/iCloudStorageView.swift
//
// Shows what's in ~/Library/Mobile Documents and CloudStorage

import SwiftUI
import AppKit

struct ICloudStorageView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = ICloudStorageViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("iCloud Storage").italic().font(PareFont.display(30)).foregroundStyle(PareColor.ink)
                        Text("Files synced via iCloud Drive, including app containers and shared documents. These take up local disk space even when stored in the cloud.")
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

                // Summary
                HStack(spacing: 12) {
                    summaryCard("iCloud Drive", vm.iCloudDriveSize, true)
                    summaryCard("App Containers", vm.containersSize, false)
                    summaryCard("CloudStorage", vm.cloudStorageSize, false)
                    summaryCard("Total Local", vm.totalSize, true)
                }
                .padding(.bottom, 22)

                if vm.isLoading {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Scanning iCloud data...").font(PareFont.mono(11)).foregroundStyle(PareColor.ink4)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    // Items sorted by size
                    Text("Largest iCloud items on this Mac")
                        .font(PareFont.display(13, weight: .medium)).foregroundStyle(PareColor.ink3)
                        .textCase(.uppercase).tracking(0.6).padding(.bottom, 16)

                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Color.clear.frame(width: 32)
                            Text("ITEM").frame(maxWidth: .infinity, alignment: .leading)
                            Text("TYPE").frame(width: 120, alignment: .leading)
                            Text("SIZE").frame(width: 90, alignment: .trailing)
                        }
                        .font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.6)
                        .padding(.horizontal, 18).padding(.vertical, 10).background(PareColor.surface2)

                        ForEach(vm.items) { item in
                            HStack(spacing: 0) {
                                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(item.isICloud ? .blue : PareColor.ink3)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink).lineLimit(1)
                                    Text(item.path).font(PareFont.mono(10)).foregroundStyle(PareColor.ink4).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Text(item.typeLabel).font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3)
                                    .textCase(.uppercase).tracking(0.5).frame(width: 120, alignment: .leading)

                                Text(item.sizeLabel).font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink2)
                                    .frame(width: 90, alignment: .trailing)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: item.url.deletingLastPathComponent().path)
                            }
                            .overlay(alignment: .bottom) { Divider() }
                        }
                    }
                    .background(PareColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                    .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
                    .padding(.bottom, 18)

                    HStack(spacing: 6) {
                        Image(systemName: "icloud").font(.system(size: 12))
                        Text("These files are synced with iCloud. Deleting them locally may remove them from all devices. Use Finder to manage iCloud storage safely.")
                    }
                    .font(PareFont.body(12)).foregroundStyle(PareColor.warning)
                    .padding(12).background(PareColor.warningSoft).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.894, green: 0.784, blue: 0.588), lineWidth: 1))
                }
            }
            .padding(.horizontal, 40).padding(.vertical, 32)
        }
        .background(PareColor.bg)
    }

    private func summaryCard(_ label: String, _ value: String, _ accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.7).textCase(.uppercase)
            Text(value).font(PareFont.display(22, weight: .medium)).foregroundStyle(accent ? PareColor.forest : PareColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 16).pareCard()
    }
}

// MARK: - ViewModel

struct ICloudItem: Identifiable {
    let id: String
    let name: String
    let path: String
    let url: URL
    let bytes: Int64
    let sizeLabel: String
    let typeLabel: String
    let isDirectory: Bool
    let isICloud: Bool
}

final class ICloudStorageViewModel: ObservableObject {
    @Published var items: [ICloudItem] = []
    @Published var isLoading = true
    @Published var iCloudDriveSize = "..."
    @Published var containersSize = "..."
    @Published var cloudStorageSize = "..."
    @Published var totalSize = "..."

    init() { scan() }

    private func scan() {
        let vm = self
        let home = FileManager.default.homeDirectoryForCurrentUser

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let fmt = { (b: Int64) -> String in ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }

            let mobileDocs = home.appendingPathComponent("Library/Mobile Documents")
            let cloudStorage = home.appendingPathComponent("Library/CloudStorage")

            var allItems: [ICloudItem] = []
            var iCloudTotal: Int64 = 0
            var containerTotal: Int64 = 0
            var cloudTotal: Int64 = 0

            // Scan Mobile Documents (iCloud Drive + app containers)
            if let contents = try? fm.contentsOfDirectory(at: mobileDocs, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for item in contents {
                    let size = SystemStorageProvider.directorySize(item)
                    let name = item.lastPathComponent
                    let isContainer = name.contains("~") // e.g. "com~apple~CloudDocs"
                    let displayName = name.replacingOccurrences(of: "com~apple~", with: "").replacingOccurrences(of: "~", with: ".")

                    if isContainer && name.contains("CloudDocs") {
                        iCloudTotal += size
                    } else {
                        containerTotal += size
                    }

                    if size > 100_000 {
                        allItems.append(ICloudItem(
                            id: item.path, name: displayName, path: "~/Library/Mobile Documents/\(name)",
                            url: item, bytes: size, sizeLabel: fmt(size),
                            typeLabel: isContainer && name.contains("CloudDocs") ? "iCloud Drive" : "App Container",
                            isDirectory: true, isICloud: true
                        ))
                    }
                }
            }

            // Scan CloudStorage (third-party: Dropbox, Google Drive, OneDrive)
            if let contents = try? fm.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for item in contents {
                    let size = SystemStorageProvider.directorySize(item)
                    cloudTotal += size
                    if size > 100_000 {
                        allItems.append(ICloudItem(
                            id: item.path, name: item.lastPathComponent, path: "~/Library/CloudStorage/\(item.lastPathComponent)",
                            url: item, bytes: size, sizeLabel: fmt(size),
                            typeLabel: "Cloud Sync", isDirectory: true, isICloud: false
                        ))
                    }
                }
            }

            allItems.sort { $0.bytes > $1.bytes }
            let total = iCloudTotal + containerTotal + cloudTotal

            DispatchQueue.main.async {
                vm.items = Array(allItems.prefix(30))
                vm.iCloudDriveSize = fmt(iCloudTotal)
                vm.containersSize = fmt(containerTotal)
                vm.cloudStorageSize = fmt(cloudTotal)
                vm.totalSize = fmt(total)
                vm.isLoading = false
            }
        }
    }
}
