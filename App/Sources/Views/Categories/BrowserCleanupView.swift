// App/Sources/Views/Categories/BrowserCleanupView.swift
//
// Safari, Chrome, Firefox — cache, history, cookies cleanup

import SwiftUI
import AppKit

struct BrowserCleanupView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = BrowserCleanupViewModel()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Browser Cleanup").italic().font(PareFont.display(30)).foregroundStyle(PareColor.ink)
                                Text("Clear caches, history, and cookies from Safari, Chrome, and Firefox.")
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
                            summaryCard("Safari", vm.safariSize)
                            summaryCard("Chrome", vm.chromeSize)
                            summaryCard("Firefox", vm.firefoxSize)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TOTAL").font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.7)
                                Text(vm.totalSize).font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.forest)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 16).pareCard()
                        }
                        .padding(.bottom, 22)

                        // Browser cards
                        ForEach(vm.browsers.indices, id: \.self) { i in
                            browserCard(index: i).padding(.bottom, 10)
                        }
                    }
                    .padding(.horizontal, 40).padding(.top, 32).padding(.bottom, 100)
                }

                // Footer
                HStack {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(vm.selectedSizeLabel).font(PareFont.display(24, weight: .medium)).foregroundStyle(PareColor.ink)
                        Text("will be cleared").font(PareFont.body(12)).foregroundStyle(PareColor.ink3)
                    }
                    Spacer()
                    Button { vm.selectAll() } label: {
                        Text("Select all").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink3).padding(.horizontal, 10).padding(.vertical, 6)
                    }.buttonStyle(.plain)
                    Button { vm.deselectAll() } label: {
                        Text("Deselect all").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink3).padding(.horizontal, 10).padding(.vertical, 6)
                    }.buttonStyle(.plain)
                    Button { vm.clean() } label: {
                        Text("Clean Selected").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10).background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 40).padding(.vertical, 18).background(.ultraThinMaterial).overlay(alignment: .top) { Divider() }
            }
            .background(PareColor.bg)

            if vm.showPaywall { PaywallModal(isPresented: $vm.showPaywall) }
        }
    }

    private func summaryCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.7).textCase(.uppercase)
            Text(value).font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 16).pareCard()
    }

    private func browserCard(index: Int) -> some View {
        let browser = vm.browsers[index]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: browser.icon).font(.system(size: 20)).foregroundStyle(browser.color)
                    .frame(width: 36, height: 36).background(PareColor.surface2).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(browser.name).font(PareFont.body(16, weight: .medium)).foregroundStyle(PareColor.ink)
                    Text(browser.installed ? "\(browser.items.count) cleanable items" : "Not installed")
                        .font(PareFont.mono(11)).foregroundStyle(browser.installed ? PareColor.ink3 : PareColor.ink4)
                }
                Spacer()
                Text(browser.totalLabel).font(PareFont.display(18, weight: .medium)).foregroundStyle(PareColor.forest)
            }

            if browser.installed {
                ForEach(browser.items.indices, id: \.self) { j in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4).stroke(vm.browsers[index].items[j].isSelected ? PareColor.ink : PareColor.lineStrong, lineWidth: 1.5).frame(width: 16, height: 16)
                            if vm.browsers[index].items[j].isSelected {
                                RoundedRectangle(cornerRadius: 4).fill(PareColor.ink).frame(width: 16, height: 16)
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(PareColor.bg)
                            }
                        }
                        Text(browser.items[j].name).font(PareFont.body(13)).foregroundStyle(PareColor.ink)
                        Spacer()
                        Text(browser.items[j].sizeLabel).font(PareFont.mono(12)).foregroundStyle(PareColor.ink3)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { vm.browsers[index].items[j].isSelected.toggle() }
                    .padding(.leading, 50)
                }
            }
        }
        .padding(22)
        .background(PareColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
        .opacity(browser.installed ? 1 : 0.5)
    }
}

// MARK: - ViewModel

struct BrowserItem: Identifiable {
    let id: String
    let name: String
    let path: URL
    let bytes: Int64
    let sizeLabel: String
    var isSelected: Bool
}

struct BrowserEntry: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let installed: Bool
    var items: [BrowserItem]
    var totalLabel: String { ByteCountFormatter.string(fromByteCount: items.reduce(0) { $0 + $1.bytes }, countStyle: .file) }
}

final class BrowserCleanupViewModel: ObservableObject {
    @Published var browsers: [BrowserEntry] = []
    @Published var showPaywall = false

    var safariSize: String { browsers.first(where: { $0.id == "safari" })?.totalLabel ?? "0 KB" }
    var chromeSize: String { browsers.first(where: { $0.id == "chrome" })?.totalLabel ?? "0 KB" }
    var firefoxSize: String { browsers.first(where: { $0.id == "firefox" })?.totalLabel ?? "0 KB" }
    var totalSize: String {
        let total = browsers.flatMap(\.items).reduce(Int64(0)) { $0 + $1.bytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    var selectedBytes: Int64 { browsers.flatMap(\.items).filter(\.isSelected).reduce(0) { $0 + $1.bytes } }
    var selectedSizeLabel: String { ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file) }

    init() { scan() }

    func selectAll() { for i in browsers.indices { for j in browsers[i].items.indices { browsers[i].items[j].isSelected = true } } }
    func deselectAll() { for i in browsers.indices { for j in browsers[i].items.indices { browsers[i].items[j].isSelected = false } } }

    func clean() {
        guard selectedBytes > 0 else { return }
        if LicenceManager.shared.wouldExceedLimit(bytes: selectedBytes) { showPaywall = true; return }
        let store = CleanedItemStore.shared
        var cleaned: Int64 = 0
        for i in browsers.indices {
            for j in browsers[i].items.indices where browsers[i].items[j].isSelected {
                let item = browsers[i].items[j]
                if FileManager.default.isDeletableFile(atPath: item.path.path) {
                    let _ = store.moveToRecoveryBin(url: item.path, fileName: item.name, originalPath: item.path.path, category: "Browser Cleanup", bytes: item.bytes)
                    cleaned += item.bytes
                }
            }
        }
        LicenceManager.shared.recordCleanup(bytes: cleaned)
        scan() // refresh
    }

    private func scan() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default
        let fmt = { (b: Int64) -> String in ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }

        // Safari
        var safariItems: [BrowserItem] = []
        let safariCache = home.appendingPathComponent("Library/Caches/com.apple.Safari")
        let safariHistory = home.appendingPathComponent("Library/Safari/History.db")
        let safariLocalStorage = home.appendingPathComponent("Library/Safari/LocalStorage")
        for (name, path) in [("Cache", safariCache), ("History", safariHistory), ("Local Storage", safariLocalStorage)] {
            if fm.fileExists(atPath: path.path) {
                let size = SystemStorageProvider.directorySize(path)
                if size > 0 { safariItems.append(.init(id: "safari-\(name)", name: name, path: path, bytes: size, sizeLabel: fmt(size), isSelected: name == "Cache")) }
            }
        }

        // Chrome
        var chromeItems: [BrowserItem] = []
        let chromeBase = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default")
        for (name, sub) in [("Cache", "Cache"), ("History", "History"), ("Cookies", "Cookies"), ("Local Storage", "Local Storage")] {
            let path = chromeBase.appendingPathComponent(sub)
            if fm.fileExists(atPath: path.path) {
                let size = SystemStorageProvider.directorySize(path)
                if size > 0 { chromeItems.append(.init(id: "chrome-\(name)", name: name, path: path, bytes: size, sizeLabel: fmt(size), isSelected: name == "Cache")) }
            }
        }
        // Chrome cache in Caches dir
        let chromeCacheDir = home.appendingPathComponent("Library/Caches/Google/Chrome/Default")
        if fm.fileExists(atPath: chromeCacheDir.path) {
            let size = SystemStorageProvider.directorySize(chromeCacheDir)
            if size > 0 { chromeItems.append(.init(id: "chrome-CacheDir", name: "Browser Cache", path: chromeCacheDir, bytes: size, sizeLabel: fmt(size), isSelected: true)) }
        }

        // Firefox
        var firefoxItems: [BrowserItem] = []
        let firefoxProfiles = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
        if let profiles = try? fm.contentsOfDirectory(at: firefoxProfiles, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for profile in profiles {
                for (name, sub) in [("Cache", "cache2"), ("History", "places.sqlite"), ("Cookies", "cookies.sqlite")] {
                    let path = profile.appendingPathComponent(sub)
                    if fm.fileExists(atPath: path.path) {
                        let size = SystemStorageProvider.directorySize(path)
                        if size > 0 { firefoxItems.append(.init(id: "firefox-\(name)-\(profile.lastPathComponent)", name: "\(name) (\(profile.lastPathComponent.prefix(8)))", path: path, bytes: size, sizeLabel: fmt(size), isSelected: name == "Cache")) }
                    }
                }
            }
        }

        browsers = [
            .init(id: "safari", name: "Safari", icon: "safari", color: .blue, installed: true, items: safariItems),
            .init(id: "chrome", name: "Google Chrome", icon: "globe", color: Color(red: 0.259, green: 0.522, blue: 0.957),
                  installed: fm.fileExists(atPath: "/Applications/Google Chrome.app"), items: chromeItems),
            .init(id: "firefox", name: "Firefox", icon: "flame", color: .orange,
                  installed: fm.fileExists(atPath: "/Applications/Firefox.app"), items: firefoxItems),
        ]
    }
}
