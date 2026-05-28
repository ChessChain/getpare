# ADR-0003: SQLite via GRDB.swift over Core Data

- Status: Accepted
- Date: 2026-05-23

## Decision

Use a single SQLite database at `~/Library/Application Support/Pare/
recovery.sqlite` accessed via GRDB.swift, with WAL mode and explicit
migrations.

## Alternatives considered

- **Core Data** — heavier API, opaque schema, harder to debug.
- **Realm** — closed source, sync features we don't need.
- **Plain `.json` blobs** — fine for a few hundred items, breaks at
  power-user scale (10k+ Recovery Bin rows over time).

## Consequences

- Positive: plain-text schema, easy to inspect with any SQLite GUI,
  mature concurrency (WAL), versioned migrations.
- Negative: one more dependency. Mitigated by GRDB's long-term track
  record and small footprint.

## Related

- Technical Design §4.3 (SQLite schema).
