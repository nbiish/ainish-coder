---
name: audit-log
description: Format, retention, and verification use cases for ~/.config/pqc-secrets/audit.log. The verification surface for "what did my agent do with my secrets?"
---

# Audit Log Format

## Location and permissions

- **Path:** `~/.config/pqc-secrets/audit.log`
- **Mode:** `0o600` (owner read+write only)
- **Created:** on first `secrets_*` call or `pqc-secrets audit` invocation
- **Lifecycle:** append-only; never edited in place

## Line format

```
<ISO8601-UTC> <agent> <action> [key=value]...
```

- `<ISO8601-UTC>` — e.g. `2026-06-09T14:52:01Z` (no subseconds, UTC)
- `<agent>` — `BROWSER_MCP_AGENT_ID` (Hermes MCP) or `$USER` (shell)
- `<action>` — one of: `unlock_agent | lock_agent | get | add | rotate
  | status | list | load | copy_to_page | add_from_clipboard`
- `[key=value]...` — zero or more flat `key=value` pairs

**No quoting in values.** Values must be flat strings (no spaces, no
special characters). If a name contains special characters, it is
rejected at write time.

## Example lines

```
2026-06-09T14:52:01Z hermes unlock_agent tab=12345 name=STRIPE_SECRET len=107
2026-06-09T14:52:03Z hermes get mode=plain name=STRIPE_SECRET tab=12345
2026-06-09T14:52:05Z hermes get mode=redact name=STRIPE_SECRET tab=12345
2026-06-09T14:53:00Z hermes lock tab=12345 name=STRIPE_SECRET
2026-06-09T15:00:00Z hermes rotate keysAffected=12
2026-06-09T15:01:00Z hermes add dryRun=false added=1 modified=0
```

## Field meanings

| Field | When | Meaning |
|---|---|---|
| `agent` | always | The BROWSER_MCP_AGENT_ID or shell user. |
| `action` | always | The operation performed. |
| `tab=<id>` | tab-initiated | Bound tab id; omitted for shell-initiated ops. |
| `name=<n>` | per-secret ops | Name of the secret touched. |
| `len=<n>` | unlock/get | Byte length of the value (NEVER the value itself). |
| `mode=plain\|redact` | get | Mode of the get operation. |
| `dryRun=true\|false` | add | Whether the add was a dry run. |
| `added=<n>` | add | Number of new keys added. |
| `modified=<n>` | add | Number of existing keys updated. |
| `keysAffected=<n>` | rotate | Number of keys re-encapsulated. |
| `reason=<text>` | lock, rotate_identity | Optional human-readable reason. |

## Retention

- **Hot file** (`audit.log`): keep forever, append-only.
- **Archive trigger:** file size > 10 MB.
- **Archive command:**
  ```bash
  ts=$(date -u +%Y-%m)
  mv ~/.config/pqc-secrets/audit.log ~/.config/pqc-secrets/audit.log.$ts
  touch ~/.config/pqc-secrets/audit.log
  chmod 600 ~/.config/pqc-secrets/audit.log
  ```
- **Total retention:** unlimited. Archived files are not deleted.
- **Size per event:** ~80 bytes. 10 MB ≈ 125,000 events.

## Verification use cases

### Did my agent read STRIPE_SECRET in the last hour?

```bash
$ grep STRIPE_SECRET ~/.config/pqc-secrets/audit.log | tail -20
2026-06-09T14:52:01Z hermes unlock_agent tab=12345 name=STRIPE_SECRET len=107
2026-06-09T14:52:03Z hermes get mode=plain name=STRIPE_SECRET tab=12345
```

### What keys were added yesterday?

```bash
$ grep -E '^[0-9-]+ hermes add' ~/.config/pqc-secrets/audit.log | grep 2026-06-08
2026-06-08T15:01:00Z hermes add dryRun=false added=1 modified=0
```

### When was the last rotation?

```bash
$ grep rotate ~/.config/pqc-secrets/audit.log | tail -1
2026-06-09T15:00:00Z hermes rotate keysAffected=12
```

### Are there any reads from an unfamiliar agent?

```bash
$ awk '{print $2}' ~/.config/pqc-secrets/audit.log | sort -u
hermes
omp
codex
```

A new agent name that you didn't expect = investigate.

### Cross-tab activity for a specific tab

```bash
$ grep 'tab=12345' ~/.config/pqc-secrets/audit.log
2026-06-09T14:52:01Z hermes unlock_agent tab=12345 name=STRIPE_SECRET len=107
2026-06-09T14:52:03Z hermes get mode=plain name=STRIPE_SECRET tab=12345
2026-06-09T14:53:00Z hermes lock tab=12345 name=STRIPE_SECRET
```

## Threat model

The audit log is the **verification surface** for "what did my agent
do with my secrets?" It is intentionally not encrypted — the user
needs to read it without ceremony. The 0o600 mode prevents other
users on the system from reading it.

The log does NOT log secret values. Even a `mode=plain` `get` event
records `len=N` but never the value. The user verifies *that* a read
happened, not *what* was read.

If an attacker has read access to the log, they know which secret
names exist and when they're accessed — but not the values. This is
the same information an attacker with keychain access would have
anyway (they can run `pqc-secrets status`).

## See also

- `references/pqc-secrets-cli.md` — CLI reference
- `references/bundle-schema.md` — bundle file format
- `references/rotation-procedure.md` — rotation runbook
