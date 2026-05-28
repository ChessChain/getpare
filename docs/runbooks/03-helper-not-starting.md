# 03 — Helper not starting

**When:** users report Pare "freezes on first launch" or sits in Limited
Mode after granting Full Disk Access.

## Steps

1. Ask the user to open Settings → General → Login Items and confirm
   `Pare Privileged Helper` is listed and enabled.
2. If not listed, prompt them to run Settings → Advanced → "Reinstall
   helper" inside Pare. The app calls `SMAppService.register`.
3. If listed but not running: `launchctl list | grep com.clearpath.pare`.
   Restart with `launchctl bootstrap user/$(id -u) /Library/LaunchAgents/
   com.clearpath.pare.helper.plist`.
4. Capture audit log (`~/Library/Logs/Pare/audit.log`) and crash report
   from `~/Library/Logs/DiagnosticReports` if needed.
