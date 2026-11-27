---
task_format: ainish/task/v1
slug: federated-machine-sync
date: 2026-11-27
status: done
branch: feat/federated-machine-sync
plan: .agents/plans/2026-11-27-15-federated-machine-sync.md
operator: nanoboozhoo
---

# Task: Federated Cross-Machine Sync, PQC CoD, Worktrees, Watchers & Remote Runner

## Objective
Fix all 6 live bugs in `--machine-sync` / `--machine-link` / `--machine-watch` and add symmetric pull/branches, worktree-aware snapshots, PQC peer discovery, bidirectional watchers/crons (macOS/Linux/WSL/Windows), `--bootstrap`, incremental bundles, and `--machine-pick` / `--machine-run`, then verify live across `mac-18gb`, `windows-128gb`, `wsl-94gb`, and `goal-first-trillion`.

## Scope
- `src/machine_sync.sh`
- `src/machine_link.sh`
- `src/machine_watch.sh`
- `src/machine_run.sh` (new)
- `bin/ainish-coder`
- `src/help.sh`
- `scripts/test-machine-sync.sh`
- `scripts/test-machine-watch.sh`
- `.agents/plans/2026-11-27-15-federated-machine-sync.md`
- `.agents/tasks/2026-11-27-15-federated-machine-sync.md`

## Progress
- [x] Audited live machine-sync/watch/link/PQC state across `mac-18gb`, `windows-128gb`, `wsl-94gb`, and `goal-first-trillion`.
- [x] Authored plan and created worktree off `origin/main` (`e6143bc`).
- [x] Implement Phases 1–3 and hermetic tests (`test-machine-sync.sh` 89/89, `test-machine-watch.sh` 45/45, `test_federation_pqc.py` 3/3).
- [x] Open PR, verify CI, and deploy/verify live across machines.
