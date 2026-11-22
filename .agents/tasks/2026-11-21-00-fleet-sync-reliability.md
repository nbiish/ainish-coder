# 2026-11-21 00 fleet sync reliability

**Lane:** ainish-coder · **Branch:** `feat/fleet-sync-reliability`
**Plan:** `.agents/plans/2026-11-21-00-fleet-sync-reliability.md`
**Status:** ready (plan written; no code changed for this plan yet)

## Why this exists

The operator reported that `--auto-commit` interrupts their work. Investigation found that framing
was too narrow: the watcher has several independent defects and is now net-negative.

## Evidence

| Finding | Value |
|---|---|
| watcher successes / failures | **45 ok vs 79 failed** in `watch.log` |
| one repo never converges | `local-router` failed every attempt through #56; `goal-first-trillion` still synced, but late and irregularly (00:33:45, 00:34:09, 00:35:19) |
| watcher is not running current code | fix `c105a35` merged 16:45, watcher started 16:46, yet pre-fix error still appears |
| `--auto-commit` committed a half-written file | skill landed as `01c379c wip(Mac): synced by --auto-commit` mid-authoring |
| `--auto-commit` holds the index lock | `Unable to create '.git/index.lock': File exists` during a manual commit |
| `--auto-commit` authors as the operator | the operator's configured identity |
| `watch.state` reports health while failing | `failed=0` at 00:32:29Z with continuous failures in the log |
| unrelated peer history | `ainish-coder` mac `dda3a90` vs win `dc9d7e2`, **0 shared commits** |

## Note on scope

The plan's T1–T7 are the watcher defects. The unrelated-history problem for `ainish-coder` itself is
NOT in that plan: it needs an operator decision on which history to keep, and until then the repo is
quarantined from the watch set (self-link removed 2026-11-21).

## Restart test (2026-11-21 00:37) — the router fault is REAL, not stuck state

Restarted the launchd agent (`launchctl kickstart -k`) and watched the next cycle:
`2026-11-21T00:37:36Z failed: …local-router (attempt 57)`.

So a fresh process with current code — including the per-process bundle-name fix — still fails on
`local-router`. This rules out "the daemon is stale / wedged" as the cause for that repo and confirms
the fleet plan's diagnosis: the delegated cycle itself is failing, and quarantine (T2) is the
immediate mitigation because nothing currently stops an unbounded retry chain.

Totals after restart: 48 ok / 81 failed.

Also confirmed only ONE watcher runs under launchd (pid 53897). A second `machine-watch --foreground`
process seen mid-cycle was the delegated child of a cycle, not a duplicate daemon — worth recording
because a naive `pgrep | wc -l` reads it as a duplicate and invites an unnecessary kill.
