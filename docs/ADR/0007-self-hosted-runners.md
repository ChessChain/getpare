# ADR-0007: Self-hosted Apple Silicon GitHub Actions runners

- Status: Accepted
- Date: 2026-05-23

## Decision

CI/CD runs on a self-hosted Mac mini (M-series) with the GitHub Actions
runner, rather than GitHub-hosted macOS runners.

## Alternatives considered

- **GitHub-hosted macOS runners** — slow, expensive at our PR volume,
  cold starts hurt feedback latency.
- **MacStadium / scaleway dedicated** — fine, but a Mac mini at ~$800
  one-time pays for itself in months at our volume.

## Consequences

- Positive: fast CI, predictable cost, full control over toolchain pinning.
- Negative: someone has to keep the runner alive, patched, and on the
  correct Xcode version. Mitigated by an Ansible playbook (see runbook
  03-helper-not-starting.md for a similar pattern).

## Related

- BRD Open Item: "Self-hosted CI runner budget approval".
