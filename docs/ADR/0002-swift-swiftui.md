# ADR-0002: Swift + SwiftUI over Electron / Catalyst

- Status: Accepted
- Date: 2026-05-23

## Context

We need a Mac app with deep system integration, low memory footprint,
native HIG conformance, and a credible path to the Mac App Store.

## Decision

Swift 5.10 + SwiftUI for the UI, with AppKit bridges where SwiftUI's
behaviour is inadequate (e.g. menu-bar status item details, complex
table interactions). Targets macOS 13+ (BRD NFR-03).

## Alternatives considered

- **Electron** — large binary, high RAM use, non-native look. Hostile
  to the brand promise of a quiet, calm app.
- **Mac Catalyst** — iOS feel, weaker keyboard handling, awkward for
  power-user features like the developer junk module.
- **AppKit + Objective-C** — mature but slower to author and harder to
  hire for in 2026.

## Consequences

- Positive: native performance, HIG conformance, declarative UI, good
  test story.
- Negative: SwiftUI gaps (NSToolbar customisation, NSAlert variants)
  still require AppKit bridges.

## Related

- BRD NFR-08 (HIG conformance, VoiceOver, Dynamic Type).
