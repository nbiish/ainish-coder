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
| one bad repo starves the rest | `local-router` retried attempts 51–55 while `goal-first-trillion` went unsynced from 00:10 |
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
