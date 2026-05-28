# ADR-0006: Sparkle for v1.0 distribution, Mac App Store in v1.1

- Status: Accepted
- Date: 2026-05-23

## Decision

Ship Pare v1.0 as a Developer-ID-signed, notarised DMG with Sparkle 2.x
for in-app updates (EdDSA-signed appcast). A parallel sandboxed-only
build targets the Mac App Store in v1.1.

## Alternatives considered

- **MAS only** — slows iteration, restricts certain entitlements that
  the helper architecture relies on today.
- **DMG only forever** — locks us out of the MAS audience.

## Consequences

- Positive: fastest iteration during product-market fit; keeps both
  channels open.
- Negative: two pipelines to maintain. ADR-007 partially offsets this
  by making the runner economics work.

## Related

- Technical Design §10 (Build / Sign / Release).
