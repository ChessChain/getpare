#!/usr/bin/env bash
# bootstrap.sh — initialise the Pare git repo and resolve SPM deps.
# Run this once from Terminal after cloning or unpacking the scaffold.

set -euo pipefail
cd "$(dirname "$0")"

# 1. Fresh git repo
rm -rf .git
git init -q
git branch -m main 2>/dev/null || true

# 2. First commit
git add .gitignore
git commit -q -m "chore: add .gitignore"

git add .
git commit -q -m "feat: scaffold Pare v1.0

- SPM workspace with App / Helper / PareKit targets (macOS 13+)
- Privileged helper architecture per ADR-0001
- 6 scanner stubs, ScannerOrchestrator, ProtectedPaths deny-list
- GRDB-backed RecoveryStore + PurgeWorker
- SwiftUI scaffold with AppCoordinator and the five primary views
- PareHelperProtocol XPC contract in PareKit/IPC
- CI/CD: ci.yml, nightly.yml, release.yml, six Tools/*.sh scripts
- ADR-0001..0007, five runbooks, BRD/UX/Tech docs copied into docs/
- VS Code: settings, recommended extensions, LLDB debug configs

Per docs/Pare_Technical_Design_v1.0.docx §9."

# 3. Resolve SPM dependencies (downloads GRDB)
if command -v swift >/dev/null 2>&1; then
    echo
    echo "Resolving Swift packages…"
    swift package resolve
fi

echo
echo "Done. Repo at $(pwd). Run 'swift build' to compile, 'swift test' to run tests."
git log --oneline
