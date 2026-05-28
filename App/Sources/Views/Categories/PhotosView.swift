// App/Sources/Views/Categories/PhotosView.swift
// Matches prototype screen-photos exactly

import SwiftUI

struct PhotosView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = PhotosViewModel()

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Header (pane-header) ─────────────────────
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Photos").italic()
                                .font(PareFont.display(30)).foregroundStyle(PareColor.ink)
                            Text("Reclaim space in your Photo Library \u{2014} screenshots, RAW originals you\u{2019}ve already exported, accidental bursts, and similar shots.")
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

                    // ── Stats (photos-stats = summary-bar) ──────
                    HStack(spacing: 12) {
                        summaryCard("Library size", vm.librarySize)
                        summaryCard("Photos", vm.photoCountFormatted)
                        summaryCardAccent("Reclaimable", vm.reclaimable)
                        summaryCardSmall("Largest set", vm.largestSet)
                    }
                    .padding(.bottom, 22)

                    // ── Section title ────────────────────────────
                    Text("By category")
                        .font(PareFont.display(13, weight: .medium))
                        .foregroundStyle(PareColor.ink3)
                        .textCase(.uppercase).tracking(0.6)
                        .padding(.bottom, 16)

                    // ── Category cards ───────────────────────────
                    ForEach(vm.categories.indices, id: \.self) { i in
                        photoCategoryCard(index: i, showThumbs: !vm.categories[i].previewURLs.isEmpty)
                            .padding(.bottom, 10)
                    }
                }
                .padding(.horizontal, 40).padding(.top, 32).padding(.bottom, 100)
            }

            // ── Action footer (sticky) ──────────────────────
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(vm.selectedSizeLabel)
                        .font(PareFont.display(24, weight: .medium))
                        .foregroundStyle(PareColor.ink)
                    Text("will be moved to Recovery Bin \u{00B7} originals can be restored for 30 days")
                        .font(PareFont.body(12))
                        .foregroundStyle(PareColor.ink3)
                }
                Spacer()
                Button { vm.deselectAll() } label: {
                    Text("Deselect all").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink3)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                }.buttonStyle(.plain)
                Button { vm.reviewAndClean(coordinator: coordinator) } label: {
                    Text("Review & Clean").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 40).padding(.vertical, 18)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider() }
        }
        if vm.showPaywall { PaywallModal(isPresented: $vm.showPaywall) }
        }
        .background(PareColor.bg)
    }

    // MARK: - Summary Cards (matching prototype summary-card)

    private func summaryCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.7).textCase(.uppercase)
            Text(value).font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 16).pareCard()
    }

    private func summaryCardAccent(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.7).textCase(.uppercase)
            Text(value).font(PareFont.display(22, weight: .medium)).foregroundStyle(PareColor.forest)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 16).pareCard()
    }

    private func summaryCardSmall(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3).tracking(0.7).textCase(.uppercase)
            Text(value).font(PareFont.display(14, weight: .medium)).foregroundStyle(PareColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 16).pareCard()
    }

    // MARK: - Photo Category Card (matching prototype photo-category)

    private func photoCategoryCard(index: Int, showThumbs: Bool) -> some View {
        let cat = vm.categories[index]
        return VStack(alignment: .leading, spacing: 0) {
            // photo-category-head
            HStack(spacing: 14) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(cat.isSelected ? PareColor.ink : PareColor.lineStrong, lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if cat.isSelected {
                        RoundedRectangle(cornerRadius: 4).fill(PareColor.ink).frame(width: 16, height: 16)
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(PareColor.bg)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { vm.categories[index].isSelected.toggle() }

                // Name + meta
                VStack(alignment: .leading, spacing: 2) {
                    Text(cat.displayName)
                        .font(PareFont.display(16, weight: .medium))
                        .tracking(-0.1)
                        .foregroundStyle(PareColor.ink)
                    Text(cat.description)
                        .font(PareFont.mono(11))
                        .foregroundStyle(PareColor.ink3)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Size
                Text("+ \(cat.sizeLabel)")
                    .font(PareFont.display(20, weight: .medium))
                    .tracking(-0.3)
                    .foregroundStyle(PareColor.forest)

                // Review button — opens Pictures folder in Finder
                Button {
                    let home = FileManager.default.homeDirectoryForCurrentUser
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: home.appendingPathComponent("Pictures").path)
                } label: {
                    Text("Review").font(PareFont.body(11, weight: .medium)).foregroundStyle(PareColor.ink2)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(PareColor.lineStrong, lineWidth: 1))
                }.buttonStyle(.plain)
            }

            // Thumbnail grid with real image previews
            if showThumbs && !cat.previewURLs.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(cat.previewURLs.indices, id: \.self) { idx in
                        PhotoThumbView(url: cat.previewURLs[idx])
                    }
                    // +N remaining count
                    if cat.itemCount > cat.previewURLs.count {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(PareColor.surface)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Text("+\((cat.itemCount - cat.previewURLs.count).formatted())")
                                    .font(PareFont.mono(9)).foregroundStyle(PareColor.ink3)
                            )
                    }
                }
                .padding(.top, 14)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 18)
        .background(PareColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
    }
}

// MARK: - Thumbnail View

private struct PhotoThumbView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(PareColor.surface2)
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(url.pathExtension.uppercased().prefix(3))
                    .font(PareFont.mono(9))
                    .foregroundStyle(PareColor.ink3)
                    .textCase(.uppercase)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(PareColor.line, lineWidth: 1))
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .utility).async {
            // Use CGImageSource for efficient thumbnail generation
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
            let options: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: 120,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 60, height: 60))
            DispatchQueue.main.async {
                self.image = nsImage
            }
        }
    }
}

// MARK: - Model + ViewModel

struct PhotoCategory: Identifiable {
    let id: String
    let name: String
    let itemCount: Int
    let unitLabel: String
    let description: String
    let sizeLabel: String
    let bytes: Int64
    var isSelected: Bool
    var previewURLs: [URL] = []   // first N file URLs for thumbnail preview

    var displayName: String {
        "\(name) \u{2014} \(itemCount.formatted()) \(unitLabel)"
    }
}

final class PhotosViewModel: ObservableObject {
    @Published var categories: [PhotoCategory] = []
    @Published var librarySize = "..."
    @Published var photoCount = 0
    @Published var reclaimable = "..."
    @Published var largestSet = "..."
    @Published var showPaywall = false

    var photoCountFormatted: String { photoCount.formatted() }
    var selectedBytes: Int64 { categories.filter(\.isSelected).reduce(0) { $0 + $1.bytes } }
    var selectedSizeLabel: String { ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file) }

    init() { loadData() }

    func deselectAll() { for i in categories.indices { categories[i].isSelected = false } }

    func reviewAndClean(coordinator: AppCoordinator) {
        let selected = categories.filter(\.isSelected)
        guard !selected.isEmpty else { return }
        if LicenceManager.shared.wouldExceedLimit(bytes: selectedBytes) {
            showPaywall = true
            return
        }
        // Record cleanup for selected photo categories
        let store = CleanedItemStore.shared
        for cat in selected {
            for url in cat.previewURLs {
                if FileManager.default.isDeletableFile(atPath: url.path) {
                    let _ = store.moveToRecoveryBin(url: url, fileName: url.lastPathComponent,
                        originalPath: url.path, category: "Photos", bytes: cat.bytes / max(1, Int64(cat.itemCount)))
                }
            }
        }
        LicenceManager.shared.recordCleanup(bytes: selectedBytes)
    }

    private func loadData() {
        let vm = self
        let home = FileManager.default.homeDirectoryForCurrentUser

        DispatchQueue.global(qos: .userInitiated).async {
            let picturesURL = home.appendingPathComponent("Pictures")
            let total = SystemStorageProvider.directorySize(picturesURL)

            var screenshots: (count: Int, bytes: Int64, urls: [URL]) = (0, 0, [])
            var rawFiles: (count: Int, bytes: Int64, urls: [URL]) = (0, 0, [])
            var similar: (count: Int, bytes: Int64, urls: [URL]) = (0, 0, [])
            var livePhotos: (count: Int, bytes: Int64, urls: [URL]) = (0, 0, [])
            var cache: (count: Int, bytes: Int64) = (0, 0)
            var fileCount = 0

            if let en = FileManager.default.enumerator(
                at: picturesURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) {
                for case let f as URL in en {
                    guard let v = try? f.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                          v.isRegularFile == true else { continue }
                    let size = Int64(v.fileSize ?? 0)
                    let ext = f.pathExtension.lowercased()
                    let name = f.lastPathComponent.lowercased()
                    fileCount += 1

                    if name.contains("screenshot") || (ext == "png" && !name.contains("thumbnail")) {
                        screenshots.count += 1; screenshots.bytes += size
                        if screenshots.urls.count < 7 { screenshots.urls.append(f) }
                    } else if ["raw", "cr2", "nef", "arw", "dng", "orf", "rw2"].contains(ext) {
                        rawFiles.count += 1; rawFiles.bytes += size
                        if rawFiles.urls.count < 7 { rawFiles.urls.append(f) }
                    } else if ["mov", "mp4", "m4v"].contains(ext) || name.contains("live") {
                        livePhotos.count += 1; livePhotos.bytes += size
                        if livePhotos.urls.count < 7 { livePhotos.urls.append(f) }
                    } else if name.contains("thumbnail") || name.contains("cache") || f.path.contains("/.") {
                        cache.count += 1; cache.bytes += size
                    } else if ["jpg", "jpeg", "heic", "heif", "webp", "gif", "tiff"].contains(ext) {
                        similar.count += 1; similar.bytes += size
                        if similar.urls.count < 7 { similar.urls.append(f) }
                    } else {
                        similar.count += 1; similar.bytes += size
                    }
                }
            }

            let fmt = { (b: Int64) -> String in ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }
            let reclaimableBytes = screenshots.bytes + rawFiles.bytes + similar.bytes

            DispatchQueue.main.async {
                vm.librarySize = fmt(total)
                vm.photoCount = fileCount
                vm.reclaimable = fmt(reclaimableBytes)

                // Find largest set
                let sets: [(String, Int64)] = [("Screenshots", screenshots.bytes), ("RAW", rawFiles.bytes), ("Similar", similar.bytes)]
                if let largest = sets.max(by: { $0.1 < $1.1 }), largest.1 > 0 {
                    vm.largestSet = "\(largest.0) \u{00B7} \(fmt(largest.1))"
                } else {
                    vm.largestSet = "\u{2014}"
                }

                vm.categories = [
                    .init(id: "screenshots", name: "Screenshots", itemCount: screenshots.count, unitLabel: "images",
                          description: "~/Pictures/Screenshots and Photos library \u{00B7} Pare keeps the most recent of any visually similar group",
                          sizeLabel: fmt(screenshots.bytes), bytes: screenshots.bytes, isSelected: screenshots.count > 0, previewURLs: screenshots.urls),
                    .init(id: "raw", name: "RAW originals already exported", itemCount: rawFiles.count, unitLabel: "files",
                          description: "RAW kept alongside the exported JPEG/HEIC of the same shot. Safe to remove if you have the export.",
                          sizeLabel: fmt(rawFiles.bytes), bytes: rawFiles.bytes, isSelected: rawFiles.count > 0, previewURLs: rawFiles.urls),
                    .init(id: "similar", name: "Similar shots (burst & near-duplicates)", itemCount: similar.count, unitLabel: "groups",
                          description: "Looks-the-same detection \u{00B7} Pare keeps the sharpest in each group, you can override.",
                          sizeLabel: fmt(similar.bytes), bytes: similar.bytes, isSelected: false, previewURLs: similar.urls),
                    .init(id: "live", name: "Live Photos & videos", itemCount: livePhotos.count, unitLabel: "items",
                          description: "Convert Live Photos to still images to reclaim ~70% per item. Not selected by default.",
                          sizeLabel: fmt(livePhotos.bytes), bytes: livePhotos.bytes, isSelected: false, previewURLs: livePhotos.urls),
                    .init(id: "cache", name: "Photos library cache & thumbnails", itemCount: cache.count, unitLabel: "derivative data",
                          description: "Photos rebuilds these on next launch \u{2014} slows first open but no data loss.",
                          sizeLabel: fmt(cache.bytes), bytes: cache.bytes, isSelected: false),
                ]
            }
        }
    }
}
