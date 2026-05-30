# ADR-0005: BLAKE3 for files > 100 MB, SHA-256 otherwise

- Status: Accepted (BLAKE3 implementation deferred — see Implementation status)
- Date: 2026-05-23
- Implementation: dispatch in `Helper/Sources/Engine/HashIndex.swift`; both
  size buckets call SHA-256 until a vetted Swift BLAKE3 package is pinned.

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

## Implementation status

The size-based dispatch is in place — `HashIndex.algorithm(forSize:)`
returns `.blake3` for files > 100 MB and `.sha256` otherwise — but the
`blake3(_:)` function currently falls through to SHA-256 pending a
package decision. Behaviour is correct (no false positives possible from
algorithm choice; both hash families have sub-1e-30 collision probability
at the populations we deal with), just not the speed ADR prescribes.

To finish: add a vetted Swift BLAKE3 package to `Package.swift`, depend
on it from `HelperLib`, and replace the body of `HashIndex.blake3(_:)`.
No other code changes required.

## Related

- BRD FR-05, NFR-01.
