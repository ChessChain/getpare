# 05 — macOS update mid-cleanup

**When:** the user begins a cleanup, macOS prompts to update / restart,
and Pare is interrupted.

## Steps

1. On next launch, the helper detects pending operations in the SQLite
   store and shows the toast "Pick up where you left off?"
2. The user accepts: the helper finishes the partially-applied move
   operations and updates the audit log.
3. The user declines: the helper rolls back any partially-moved files
   from the staging area inside the Recovery Bin directory.
