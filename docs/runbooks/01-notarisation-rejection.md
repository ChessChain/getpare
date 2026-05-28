# 01 — Notarisation rejection

**When:** the release workflow fails at the `notarise` step, or `notarytool
log` returns issues.

## Steps

1. Pull the notarisation log: `xcrun notarytool log <submission-id>
   --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID"`.
2. Most common cause: a nested binary missing the hardened runtime or
   secure timestamp. Look at the `path` field in each issue.
3. Re-sign locally with `Tools/sign-helper.sh` and verify with
   `codesign -dvvv --entitlements - <bundle>`.
4. Re-submit. Notarisation usually completes in under 10 minutes; if it
   exceeds 30 the workflow already pages on-call.

## Escalation

- If multiple consecutive releases fail the same check, open an Apple
  Developer support ticket and pin the toolchain via `xcode-select`.
