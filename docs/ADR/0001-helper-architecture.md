# ADR-0001: Privileged helper over inline Full Disk Access

- Status: Accepted
- Date: 2026-05-23
- Authors: ClearPath Digital Engineering
- Reviewers: Security Reviewer, Product Sponsor

## Context

Pare needs to scan locations protected by macOS TCC (Full Disk Access).
The macOS App Sandbox is incompatible with FDA when granted to a sandboxed
app, but it's a hard requirement for Mac App Store distribution and a
strong signal for direct-distribution trust.

## Decision

Ship Pare as two binaries: a sandboxed SwiftUI app and a privileged
helper (`com.clearpath.pare.helper`) installed via `SMAppService.daemon`.
The helper holds FDA; the UI is sandboxed and communicates with the
helper only over an XPC interface defined in `PareKit/IPC/`.

## Alternatives considered

- **Single non-sandboxed app with FDA.** Larger attack surface, no path
  to the Mac App Store later (ADR-006 keeps that door open).
- **Inline FDA via temporary entitlement.** Apple does not grant this for
  consumer apps in our category.
- **Run all work in the app and prompt for individual folders.** Defeats
  the user value proposition; can't reach caches without FDA.

## Consequences

- Positive: smaller blast radius if the UI is compromised; survives UI
  restarts for long scans and Recovery Bin purges; reviewable for MAS.
- Negative: installation flow has an extra step (System Settings →
  Login Items); two binaries to sign and notarise.
- Risks: SMAppService is macOS 13+. The BRD's NFR-03 already targets
  Ventura+, so this is consistent.

## Related

- Technical Design §3 (High-Level Architecture), §7 (Security Model).
