# ADR-0004: Sandboxed Recovery Bin (not macOS Trash)

- Status: Accepted
- Date: 2026-05-23

## Decision

Items removed by Pare move to `~/Library/Application Support/Pare/
Recovery/<scanID>/` and are tracked in our SQLite store. After 30 days
they are permanently purged by a background worker.

## Alternatives considered

- **macOS Trash** — globally visible, user can empty it accidentally,
  no API to enumerate or restore individual items reliably.
- **In-place rename / hide** — risks confusing other apps that index
  the user's folders.

## Consequences

- Positive: 100% recoverable for 30 days; isolated from Finder's empty-
  trash behaviour; auditable via our store.
- Negative: occupies disk until purge; counts against user storage.
  Mitigated by the size-cap in Settings → Advanced (default 10 GB).

## Related

- UX §6.6 (Recovery Bin), BR-04 (Recovery Bin behavior).
