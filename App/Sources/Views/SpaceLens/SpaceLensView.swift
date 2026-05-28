// App/Sources/Views/SpaceLens/SpaceLensView.swift
// v0.8 — Two-pane file browser with bubble visualization

import SwiftUI
import AppKit

struct SpaceLensView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = SpaceLensViewModel()
    @State private var showPaywall = false

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    (Text("Space ") + Text("Lens").italic())
                        .font(PareFont.display(30)).foregroundStyle(PareColor.ink)
                    Text("Browse every folder on your Mac \u{2014} drill down to individual files, see what\u{2019}s heavy, decide what to clean.")
                        .font(PareFont.body(13)).foregroundStyle(PareColor.ink3)
                }
                Spacer()
                Button { coordinator.route = .dashboard } label: {
                    Text("Back to Dashboard").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 40).padding(.top, 32).padding(.bottom, 16)

            // ── Breadcrumb path bar ──────────────────────────
            HStack(spacing: 6) {
                // Back / Forward
                HStack(spacing: 4) {
                    Button { vm.goBack() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .medium))
                            .frame(width: 24, height: 22)
                            .foregroundStyle(vm.canGoBack ? PareColor.ink3 : PareColor.ink4)
                            .background(PareColor.surface).clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(PareColor.line, lineWidth: 1))
                    }.buttonStyle(.plain).disabled(!vm.canGoBack)

                    Button { vm.goForward() } label: {
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium))
                            .frame(width: 24, height: 22)
                            .foregroundStyle(vm.canGoForward ? PareColor.ink3 : PareColor.ink4)
                            .background(PareColor.surface).clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(PareColor.line, lineWidth: 1))
                    }.buttonStyle(.plain).disabled(!vm.canGoForward)
                }
                .padding(.trailing, 6)
                Divider().frame(height: 16)
                .padding(.trailing, 6)

                // Crumbs
                ForEach(vm.breadcrumbs.indices, id: \.self) { i in
                    if i > 0 {
                        Text("/").font(PareFont.mono(12)).foregroundStyle(PareColor.ink4)
                    }
                    Button { vm.navigateToCrumb(i) } label: {
                        Text(vm.breadcrumbs[i].name)
                            .font(PareFont.body(13, weight: i == vm.breadcrumbs.count - 1 ? .medium : .regular))
                            .foregroundStyle(i == vm.breadcrumbs.count - 1 ? PareColor.ink : PareColor.ink2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(i == vm.breadcrumbs.count - 1 ? PareColor.surface2 : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }.buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
            .padding(.horizontal, 40).padding(.bottom, 16)

            // ── Two-pane body ────────────────────────────────
            HStack(spacing: 16) {
                // Left: file list
                VStack(spacing: 0) {
                    // List header
                    HStack {
                        Text(vm.currentName).font(PareFont.mono(10, weight: .medium)).foregroundStyle(PareColor.ink3)
                            .textCase(.uppercase).tracking(0.6)
                        Spacer()
                        Text("\(vm.entries.count) items").font(PareFont.mono(10)).foregroundStyle(PareColor.ink2)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(PareColor.surface2)

                    Divider()

                    // Rows
                    if vm.isLoading {
                        VStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Scanning...").font(PareFont.mono(11)).foregroundStyle(PareColor.ink4)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(vm.entries) { entry in
                                    LensRowView(entry: entry, isSelected: vm.selectedId == entry.id) {
                                        vm.selectedId = entry.id
                                    } onDoubleClick: {
                                        if entry.isDirectory { vm.drillInto(entry) }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: 360)
                .background(PareColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))

                // Right: bubble visualization
                VStack(spacing: 0) {
                    if vm.entries.isEmpty && !vm.isLoading {
                        VStack(spacing: 8) {
                            Text("This folder is empty").font(PareFont.display(22)).foregroundStyle(PareColor.ink)
                            Text("Go back up to keep exploring.").font(PareFont.body(13)).foregroundStyle(PareColor.ink3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.isLoading {
                        VStack(spacing: 8) {
                            ProgressView().controlSize(.regular)
                            Text("Loading...").font(PareFont.mono(11)).foregroundStyle(PareColor.ink4)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        BubbleCanvas(entries: vm.entries, selectedId: $vm.selectedId,
                            onTap: { entry in
                                vm.selectedId = entry.id
                            },
                            onDrill: { entry in
                                if entry.isDirectory { vm.drillInto(entry) }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PareColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: PareRadius.standard))
                .overlay(RoundedRectangle(cornerRadius: PareRadius.standard).stroke(PareColor.line, lineWidth: 1))
            }
            .frame(maxHeight: 540)
            .padding(.horizontal, 40)

            // ── Footer ───────────────────────────────────────
            HStack(spacing: 20) {
                // Disk usage
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Macintosh HD").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink)
                        Text(vm.diskUsageLabel).font(PareFont.mono(11)).foregroundStyle(PareColor.ink3)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(PareColor.line)
                            RoundedRectangle(cornerRadius: 3).fill(PareColor.forest)
                                .frame(width: geo.size.width * vm.diskUsagePercent)
                        }
                    }.frame(height: 6)
                }
                .frame(maxWidth: 280)

                // Selection info
                HStack(spacing: 8) {
                    Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(PareColor.ink4)
                    if let sel = vm.selectedEntry {
                        Text(sel.name).font(PareFont.body(12)).foregroundStyle(PareColor.ink2).lineLimit(1)
                        Text(sel.sizeLabel).font(PareFont.mono(12, weight: .medium)).foregroundStyle(PareColor.ink)
                    } else {
                        Text("No items selected").font(PareFont.body(12)).foregroundStyle(PareColor.ink4)
                    }
                }

                Spacer()

                // Actions
                Button {
                    if let sel = vm.selectedEntry {
                        NSWorkspace.shared.selectFile(sel.url.path, inFileViewerRootedAtPath: sel.url.deletingLastPathComponent().path)
                    }
                } label: {
                    Text("Reveal in Finder").font(PareFont.body(13, weight: .medium)).foregroundStyle(PareColor.ink2)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.lineStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(vm.selectedEntry == nil)
                .opacity(vm.selectedEntry != nil ? 1 : 0.4)

                Button {
                    if let sel = vm.selectedEntry, !sel.isProtected {
                        if LicenceManager.shared.wouldExceedLimit(bytes: sel.bytes) {
                            showPaywall = true
                        } else {
                            let _ = CleanedItemStore.shared.moveToRecoveryBin(
                                url: sel.url, fileName: sel.name,
                                originalPath: sel.url.path, category: "Space Lens", bytes: sel.bytes)
                            LicenceManager.shared.recordCleanup(bytes: sel.bytes)
                            vm.loadCurrentDirectory()
                        }
                    }
                } label: {
                    Text("Move to Recovery Bin").font(PareFont.body(13, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(PareColor.ink).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(vm.selectedEntry == nil || (vm.selectedEntry?.isProtected ?? true))
                .opacity(vm.selectedEntry != nil && !(vm.selectedEntry?.isProtected ?? true) ? 1 : 0.4)
            }
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider() }
        }
        .background(PareColor.bg)
        if showPaywall { PaywallModal(isPresented: $showPaywall) }
        }
    }
}

// MARK: - Row View

private struct LensRowView: View {
    let entry: LensEntry
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleClick: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            if entry.isDirectory {
                Image(systemName: "folder.fill").font(.system(size: 14)).foregroundStyle(PareColor.forest)
                    .frame(width: 22)
            } else {
                Image(systemName: fileIcon(entry.name)).font(.system(size: 14)).foregroundStyle(PareColor.ink3)
                    .frame(width: 22)
            }

            // Name
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name).font(PareFont.body(13, weight: .medium))
                    .foregroundStyle(entry.isProtected ? PareColor.ink3 : PareColor.ink)
                    .lineLimit(1).truncationMode(.middle)
                if entry.isDirectory {
                    Text("\(entry.childCount) items").font(PareFont.mono(11)).foregroundStyle(PareColor.ink3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Size
            Text(entry.sizeLabel).font(PareFont.mono(12)).foregroundStyle(PareColor.ink2)
                .frame(width: 80, alignment: .trailing)

            // Chevron
            if entry.isDirectory {
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(PareColor.ink4)
            } else {
                Color.clear.frame(width: 10)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(isSelected ? PareColor.accentSoft : (isHovered ? PareColor.surface2 : Color.clear))
        .overlay(alignment: .leading) {
            if isSelected { Rectangle().fill(PareColor.forest).frame(width: 2) }
        }
        .overlay(alignment: .bottom) { Divider() }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onDoubleClick() }
        .onTapGesture(count: 1) { onTap() }
    }

    private func fileIcon(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "heic", "gif": return "photo"
        case "mov", "mp4": return "film"
        case "mp3", "wav", "m4a": return "music.note"
        case "zip", "dmg", "pkg", "gz": return "archivebox"
        case "app": return "app"
        default: return "doc"
        }
    }
}

// MARK: - Bubble Canvas

private struct BubbleCanvas: View {
    let entries: [LensEntry]
    @Binding var selectedId: String?
    let onTap: (LensEntry) -> Void
    let onDrill: (LensEntry) -> Void

    @State private var bubbles: [BubbleLayout] = []
    @State private var tooltipEntry: LensEntry? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bubbles) { b in
                    BubbleView(
                        entry: b.entry, radius: b.radius,
                        isSelected: selectedId == b.entry.id
                    ) {
                        // Single click: folders drill in, files select
                        if b.entry.isDirectory {
                            onDrill(b.entry)
                        } else {
                            onTap(b.entry)
                        }
                    }
                    .position(x: b.x, y: b.y)
                }

                // Tooltip for hovered bubble
                if let tip = tooltipEntry {
                    VStack(spacing: 2) {
                        Text(tip.name).font(PareFont.body(12, weight: .medium)).foregroundStyle(PareColor.ink)
                        Text(tip.sizeLabel).font(PareFont.mono(11)).foregroundStyle(PareColor.ink3)
                        if tip.isDirectory {
                            Text("\(tip.childCount) items \u{00B7} click to open").font(PareFont.mono(10)).foregroundStyle(PareColor.forest)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(PareColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PareColor.line, lineWidth: 1))
                    .position(x: geo.size.width / 2, y: 30)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: entries.count) { _ in rebuildLayout(in: geo.size) }
            .onChange(of: entries.first?.bytes ?? 0) { _ in rebuildLayout(in: geo.size) }
            .onAppear { rebuildLayout(in: geo.size) }
            .onReceive(NotificationCenter.default.publisher(for: .init("LensBubbleHover"))) { notif in
                withAnimation(.easeOut(duration: 0.15)) {
                    tooltipEntry = notif.object as? LensEntry
                }
            }
        }
    }

    private func rebuildLayout(in size: CGSize) {
        let sorted = entries.filter { $0.bytes > 0 }.sorted { $0.bytes > $1.bytes }.prefix(30)
        guard !sorted.isEmpty else { withAnimation { bubbles = [] }; return }
        let maxBytes = sorted.first?.bytes ?? 1
        let minR: CGFloat = 16
        let maxR = min(size.width, size.height) * 0.24

        var placed: [(x: CGFloat, y: CGFloat, r: CGFloat)] = []
        var result: [BubbleLayout] = []
        let cx = size.width / 2
        let cy = size.height / 2

        for entry in sorted {
            let fraction = sqrt(Double(entry.bytes) / Double(max(1, maxBytes)))
            let r = minR + (maxR - minR) * CGFloat(fraction)

            // Find a position that doesn't overlap
            var bestX = cx
            var bestY = cy
            var found = false

            // Try spiral positions
            for step in 0..<200 {
                let angle = Double(step) * 0.618 * 2 * .pi
                let dist = CGFloat(step) * 3.0 + r
                let tx = cx + CGFloat(cos(angle)) * dist
                let ty = cy + CGFloat(sin(angle)) * dist

                // Check bounds
                guard tx - r > 4, tx + r < size.width - 4,
                      ty - r > 4, ty + r < size.height - 4 else { continue }

                // Check overlap with placed bubbles
                let overlaps = placed.contains { p in
                    let dx = tx - p.x
                    let dy = ty - p.y
                    let minDist = r + p.r + 4
                    return (dx * dx + dy * dy) < (minDist * minDist)
                }
                if !overlaps {
                    bestX = tx
                    bestY = ty
                    found = true
                    break
                }
            }

            if !found {
                // Fallback: place with some offset
                bestX = cx + CGFloat.random(in: -size.width * 0.3...size.width * 0.3)
                bestY = cy + CGFloat.random(in: -size.height * 0.3...size.height * 0.3)
                bestX = max(r + 4, min(size.width - r - 4, bestX))
                bestY = max(r + 4, min(size.height - r - 4, bestY))
            }

            placed.append((bestX, bestY, r))
            result.append(BubbleLayout(id: entry.id, entry: entry, x: bestX, y: bestY, radius: r))
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            bubbles = result
        }
    }

    struct BubbleLayout: Identifiable {
        let id: String
        let entry: LensEntry
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
    }
}

// MARK: - Individual Bubble

private struct BubbleView: View {
    let entry: LensEntry
    let radius: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    private var fillColors: [Color] {
        if entry.isProtected {
            return [Color(red: 0.608, green: 0.596, blue: 0.561), Color(red: 0.373, green: 0.365, blue: 0.345)]
        } else if entry.isDirectory {
            return [Color(red: 0.173, green: 0.478, blue: 0.333), Color(red: 0.055, green: 0.255, blue: 0.153)]
        } else {
            return [Color(red: 0.722, green: 0.455, blue: 0.173), Color(red: 0.478, green: 0.278, blue: 0.082)]
        }
    }

    var body: some View {
        ZStack {
            // Shadow ring on hover
            if isHovered {
                Circle()
                    .fill(Color.clear)
                    .frame(width: radius * 2 + 6, height: radius * 2 + 6)
                    .shadow(color: fillColors[0].opacity(0.4), radius: 8)
            }

            Circle()
                .fill(RadialGradient(
                    colors: fillColors,
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0, endRadius: radius
                ))
                .frame(width: radius * 2, height: radius * 2)

            // Labels
            VStack(spacing: 2) {
                if entry.isDirectory && radius > 18 {
                    Image(systemName: "folder.fill")
                        .font(.system(size: min(14, radius * 0.2)))
                        .opacity(0.7)
                }
                if radius > 22 {
                    Text(entry.name)
                        .font(.system(size: max(8, min(13, radius * 0.2)), weight: .medium))
                        .lineLimit(radius > 40 ? 2 : 1)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.center)
                }
                if radius > 32 {
                    Text(entry.sizeLabel)
                        .font(.system(size: max(7, min(11, radius * 0.16))).monospacedDigit())
                        .opacity(0.75)
                }
                if entry.isDirectory && radius > 45 {
                    Text("\(entry.childCount) items")
                        .font(.system(size: max(7, min(9, radius * 0.12))))
                        .opacity(0.6)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: radius * 1.5)

            // Selection ring
            Circle()
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2.5)
                .frame(width: radius * 2, height: radius * 2)

            // Hover ring
            if isHovered && !isSelected {
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    .frame(width: radius * 2, height: radius * 2)
            }
        }
        .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.06 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPressed)
        .onHover { hovering in
            isHovered = hovering
            NotificationCenter.default.post(name: .init("LensBubbleHover"), object: hovering ? entry : nil)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onTap()
                }
        )
        .help(entry.isDirectory ? "\(entry.name) — \(entry.sizeLabel) — click to open" : "\(entry.name) — \(entry.sizeLabel)")
    }
}
