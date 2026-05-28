# Pare CLI (v1.1)

Placeholder. The `pare` command-line tool is targeted for v1.1 per the
BRD roadmap. It will share the same XPC interface (`PareKit/IPC`) and
helper as the main app, so a scan kicked off from the terminal stays in
sync with the GUI.

Planned subcommands:

| Command | Purpose |
|---|---|
| `pare scan` | Run a Smart Scan and print results as a table or JSON. |
| `pare clean --category developer` | Run a category cleanup with explicit user confirmation. |
| `pare bin list` | Show the Recovery Bin. |
| `pare bin restore <id>` | Restore a single item. |
| `pare bin empty` | Permanently empty the Recovery Bin. |
| `pare report --format pdf out.pdf` | Generate the cleanup report. |

No source files in this folder yet — the SPM target is intentionally absent
until v1.1 planning lands.
