# ADR-0005: BLAKE3 for files > 100 MB, SHA-256 otherwise

- Status: Accepted
- Date: 2026-05-23

## Decision

The duplicate scanner hashes files using SHA-256 by default. For files
larger than 100 MB it switches to BLAKE3, which is ~5× faster on large
inputs with comparable collision resistance for our use case.

## Alternatives considered

- **SHA-256 only** — simpler but slow on the developer-machine media
  files this product targets.
- **xxHash3** — faster still but weaker collision properties. We do not
  want to risk a false-positive duplicate.
- **MD5** — broken; rejected for any deletion-adjacent operation.

## Consequences

- Positive: scan time stays under the NFR-01 60-second budget even on
  Macs with terabyte-scale media libraries.
- Negative: two hash code paths to maintain. Mitigated by isolating to
  `HashIndex.hash(_:)`.

## Related

- BRD FR-05, NFR-01.
