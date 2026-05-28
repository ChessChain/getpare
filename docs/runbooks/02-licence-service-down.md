# 02 — Licence service down

**When:** `api.pare.app/licence` synthetic checks fail 3 times in a row
(Better Stack pages on-call).

## Steps

1. Confirm scope: is it the entire endpoint, or a specific region? Check
   the status page (`status.pare.app`).
2. Inspect the load balancer + app logs. If the failure is a single
   instance, drain it and let auto-scaling replace it.
3. If the failure is global, flip the licence service to "permissive"
   mode: clients accept any signed receipt for the offline grace period.
4. Communicate via the in-app banner (Sparkle appcast `news` field).

## Escalation

- DB outages: page the on-call DBA via PagerDuty.
