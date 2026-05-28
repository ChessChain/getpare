# Pare

A privacy-first storage cleanup application for macOS.

**Sponsor:** Jumoke — ClearPath Digital
**Status:** Pre-development scaffold. BRD v1.1, UX Design v1.0, Technical Design v1.0 are complete drafts pending sign-off.

---

## Quick start

```bash
# 1. Resolve and build everything
swift build

# 2. Run tests for all targets
swift test

# 3. Generate the Xcode project (for signing/notarisation in the release pipeline)
# Generated lazily; you can also work entirely from VS Code with the Swift extension.
xed .
```

Pare is structured as a Swift Package Manager workspace with three targets — see `Package.swift` for the canonical layout. The development host runs macOS 13+ with Xcode 16 and Swift 5.10.

---

## Architecture in one paragraph

Pare runs as three artefacts: a **sandboxed SwiftUI app** (`App/`) that has no direct file-system access, a **privileged helper** (`Helper/`) that holds Full Disk Access and performs every scan and deletion, and a shared framework (`PareKit/`) that defines the data models and the XPC contract between them. The UI never reads or writes user files directly — it issues requests over `NSXPCConnection`, and the helper returns results. Two-phase deletion: items move to a sandboxed 30-day Recovery Bin at `~/Library/Application Support/Pare/Recovery/`, never to the macOS Trash. See [`docs/Technical-Design.docx`](docs/Technical-Design.docx) and the ADRs in [`docs/ADR/`](docs/ADR/) for the rationale behind each decision.

---

## Folder tour

| Folder | What it holds |
|---|---|
| `Package.swift` | SPM workspace root. Three products: `Pare` (app), `ParePrivilegedHelper` (helper), `PareKit` (shared library). |
| `App/Sources/` | SwiftUI views, view-models, theme tokens, coordinators. Imports `PareKit`. |
| `Helper/Sources/` | Scanners, the orchestrator, the deletion engine, protected-paths deny-list, SQLite-backed Recovery store. Imports `PareKit` + `GRDB`. |
| `PareKit/Sources/` | Models (`ScanItem`, `RecoveryItem`, etc.), the `PareHelperProtocol` XPC contract, and utilities. Imported by both other targets. |
| `Tools/` | Shell scripts for the release pipeline: signing, notarisation, DMG packaging, Sparkle appcast signing. |
| `.github/workflows/` | CI on every PR, nightly notarisation dry-runs, tagged release pipeline. Runs on self-hosted Apple Silicon Mac mini runners (ADR-007). |
| `docs/` | BRD, UX Design, Technical Design, ADRs, runbooks, and the HTML prototype. |
| `.vscode/` | Editor config, recommended extensions, and a Swift debug launch profile. |
| `CLI/` | Placeholder for the `pare` CLI tool, targeted for v1.1. |
| `fastlane/` | Optional release automation. Empty until the first release run. |

---

## Development on VS Code

Pare is set up to be edited and debugged in VS Code without launching Xcode. The recommended extensions install on first open from `.vscode/extensions.json`:

- **Swift** (`sswg.swift-lang`) — official SourceKit-LSP integration, code completion, jump-to-definition.
- **CodeLLDB** (`vadimcn.vscode-lldb`) — Swift debugging via LLDB.
- **swift-format** (`vknabel.vscode-apple-swift-format`) — formatting on save.

Open the workspace folder in VS Code, accept the prompt to install the recommended extensions, and the SourceKit-LSP server will boot from your installed toolchain (Xcode's `swift` by default). Build via the Swift extension command palette or by running `swift build` in the integrated terminal. Debugging is wired up in `.vscode/launch.json`.

For final signing, notarisation, and release builds, you still need Xcode installed locally (the release workflow in `.github/workflows/release.yml` shells out to `xcodebuild` and `notarytool`). Day-to-day development — including unit tests — runs entirely from VS Code.

---

## Source documents

| Document | Path |
|---|---|
| Business Requirements (BRD v1.1) | [`docs/Pare_BRD_v1.1.docx`](docs/Pare_BRD_v1.1.docx) |
| UX Design v1.0 | [`docs/Pare_UX_Design_v1.0.docx`](docs/Pare_UX_Design_v1.0.docx) |
| Technical Design v1.0 | [`docs/Pare_Technical_Design_v1.0.docx`](docs/Pare_Technical_Design_v1.0.docx) |
| Interactive HTML prototype | [`docs/prototypes/`](docs/prototypes/) (v0.1 → v0.6) |
| Architecture Decision Records | [`docs/ADR/`](docs/ADR/) (ADR-001 through ADR-007) |
| Operational runbooks | [`docs/runbooks/`](docs/runbooks/) |

The original BRD/UX/Tech-Design `.docx` files remain at the project root for convenience.

---

## Contribution model

For v1.0 development, only ClearPath Digital engineers should push to `main`. Feature work happens on branches named `feat/<short-description>` or `fix/<short-description>`. Every PR runs the `ci.yml` workflow: build, unit tests, format check, lint. Tagging a commit `v1.x.y` triggers `release.yml`, which builds a universal binary, signs it, notarises via `notarytool`, packages a DMG, signs the Sparkle appcast with the EdDSA key, and uploads to the release CDN.

ADRs are append-only. To propose a significant technical change, copy `docs/ADR/TEMPLATE.md`, fill it in, and open a PR titled `ADR-NNNN: <decision>`.

---

## Roadmap

| Phase | Target | Deliverable |
|---|---|---|
| P1 | Jun 2026 | BRD sign-off, scaffold (this repo) |
| P2 | Jul 2026 | High-fi Figma, ADRs accepted |
| P3 | Sep 2026 | Alpha — Smart Scan, System Junk, Large Files |
| P4 | Nov 2026 | Closed beta — Duplicates, Uninstaller, Recovery Bin, Dashboard |
| P5 | Jan 2027 | Public v1.0 launch via Sparkle/DMG |
| P6 | Mar 2027 | v1.1 — scheduling, reporting, localisation, CLI |

---

## Licence

MIT — see [`LICENSE`](LICENSE).
