# 04 — Recovery Bin disk pressure

**When:** the bin itself exceeds the user's configured cap (default 10 GB),
or the disk falls below 5% free.

## Steps

1. The auto-purge worker should already be running daily. Check
   `~/Library/Logs/Pare/audit.log` for `Purge run` entries in the last 24h.
2. If purges aren't happening, restart the helper (runbook 03).
3. Confirm the user's Settings → Advanced → Recovery Bin size cap. Raise
   it if they prefer; lower it to force a purge.
4. Worst case: empty the bin manually via Settings → Advanced → "Empty
   Recovery Bin now" (requires typed confirmation).
