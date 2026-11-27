---
plan_format: ainish/plan/v1
slug: federated-machine-sync
date: 2026-11-27
status: done
branch: feat/federated-machine-sync
worktree: /Users/nbiish/code/ainish-coder-worktrees/feat-federated-machine-sync
task_record: .agents/tasks/2026-11-27-15-federated-machine-sync.md
integration: new-pr
operator: nanoboozhoo
---

# Plan: True Federated Cross-Machine Sync, PQC CoD Wiring, Worktrees, Bidirectional Watchers & Remote Agent Runner

## 1. Objective

Fix all 6 live bugs uncovered in the `--machine-sync` / `--machine-link` / `--machine-watch` audit and complete the missing federated multi-machine/cloud capabilities so agents and operators can hop seamlessly across `mac-18gb`, `windows-128gb`, `wsl-94gb`, and cloud compute hosts (including parallel worktrees and cron/SSH tasks on multi-platform repos like `goal-first-trillion`):

1. **Symmetric pull + branch materialization:** When `--pull` or `--both` succeeds, safely fast-forward the local checked-out branch if clean (`--ff-peers`, default on) and materialize peer branches locally when `--branches` is set (additive create + fast-forward behind non-checked-out branches; diverged branches reported and never moved).
2. **Fix `--machine-sync --all` flag forwarding & subshell isolation:** Run each linked repo in a true subshell so `_MS_*` globals never leak, and forward all flags (`--branches`, `--latest`, `--linked-only`, `--auto-commit`, `--no-auto-commit`, `--quiet`, `--min-ram`, `--kind`, `--as`, `--machines-file`, `--links-file`, `--bootstrap`, `--full-bundle`).
3. **Fix `_ml_cli_path()` worktree resolution:** Resolve worktrees back to the durable main checkout before writing `post-commit` / `post-merge` hooks so hooks never point at deleted worktrees.
4. **Fix PQC Federation CoD peer discovery & runtime resolution:** Resolve `federation_pqc.py` on peers from `<target-repo>/src/federation_pqc.py` → `<peer-code-root>/ainish-coder/src/federation_pqc.py` → `$HOME/.local/share/ainish-coder/src/federation_pqc.py`, probe PQC-capable Python (`python3` / `uv run --with cryptography` on POSIX; `py -3` / `python` on Windows), never silently downgrade to plaintext, and surface PQC federation status in `--machine-sync --doctor`.
5. **Worktree-aware fingerprinting & per-worktree WIP snapshotting:** Inspect active linked worktrees (`git worktree list --porcelain`) in `_mw_fingerprint` and `_ms_wip_snapshot` so uncommitted work in parallel agent worktrees is detected by `--machine-watch` and snapshotted onto `refs/machine-sync/<machine>/<wt-branch>` without auto-committing inside active agent worktrees.
6. **Skip `_ms_smoke_peer` for non-`ainish-coder` repos:** Avoid 3 wasted SSH round trips per sync on target repos that don't ship `bin/ainish-coder`.
7. **Bidirectional pull heartbeat & cross-platform service/cron installers:** Add `--pull-interval SECONDS` (default 30s, `0` disables) + `--pull-now` to `--machine-watch`, and add service/cron installers (`--install`, `--status`, `--uninstall`) for Windows Task Scheduler (`schtasks.exe`) and WSL/Linux (`systemd --user` with managed `crontab` fallback).
8. **Cloud/peer bootstrap & incremental bundle transfer:** Add `--bootstrap` to initialize/clone a missing peer repo from a bundle over SSH on first sync, and incremental bundle transfer (ref-equality skip + peer-verified basis commits with automatic full-bundle fallback and `--full-bundle` opt-out).
9. **Capacity-aware peer selector & remote SSH agent task runner (`--machine-pick` / `--machine-run`):** Add `src/machine_run.sh` implementing `--machine-pick` (filters by `--min-ram`, `--kind`, `--machine`, probes SSH reachability, returns highest-capacity peer) and `--machine-run` (sync-before → execute command over SSH in peer repo or isolated `--worktree` → sync-after, returning remote exit code fail-closed).
10. **Live deployment & end-to-end verification:** Wire PQC `cryptography` on `windows-128gb`, symmetrically link `goal-first-trillion` across `mac-18gb` ↔ `windows-128gb` ↔ `wsl-94gb`, re-arm `goal-first-trillion` hooks with durable CLI paths, install cross-platform watchers/crons, and verify real ML-KEM-768 + ML-DSA-65 PQC CoD exchange + `--machine-run` live across machines.

## 2. Threat Model & Constraints

- **Assets:** Multi-platform git repositories (`ainish-coder`, `goal-first-trillion`), uncommitted working-tree state across parallel worktrees, ML-KEM-768 / ML-DSA-65 federation keys (`~/.config/ainish-coder/federation-keys/`), and remote SSH execution authority across `mac-18gb`, `windows-128gb`, `wsl-94gb`, and cloud peers.
- **Threats & Controls:**
  - *Silent data loss / overwrite:* Never overwrite dirty working trees or diverged branches on either sender or receiver; `--auto-commit` never runs inside sibling worktrees or repos with `.agents/no-watcher-autocommit`.
  - *PQC downgrade / tampering:* `.agents/federation/{date}.md` exchanges fail closed if FIPS 203/204 primitives are unavailable or pinned peer fingerprints change; never fall back to plaintext transfer; OS read-only locks stay intact.
  - *Remote shell injection / quoting bugs:* Quote paths/arguments cleanly for both POSIX sh and Windows PowerShell; `--machine-run` executes only the operator/agent-supplied command on explicitly selected/trusted peers over existing SSH `BatchMode=yes` keys, and propagates non-zero exit codes fail-closed.
  - *No secrets in commits, logs, tests, or prompts.* `AGENTS.md` and `LICENSE` untouched.

## 3. Checklist

- [x] Phase 1: Fix symmetric pull/branches, `--all` subshell & flag forwarding, `_ml_cli_path` worktree resolution, PQC peer script/Python discovery + doctor reporting, worktree-aware snapshots/fingerprinting, and `_ms_smoke_peer` guard.
- [x] Phase 2: Add `--pull-interval` / `--pull-now` to `machine_watch.sh` + Windows Task Scheduler & WSL/Linux cron installers (`--install`, `--status`, `--uninstall`).
- [x] Phase 3: Add `--bootstrap` & incremental bundle transfer to `machine_sync.sh`, plus `src/machine_run.sh` (`--machine-pick`, `--machine-run`) wired into `bin/ainish-coder` and `src/help.sh`.
- [x] Add hermetic regression tests to `scripts/test-machine-sync.sh` and `scripts/test-machine-watch.sh` covering every new behavior and bug fix, and verify all test suites pass.
- [x] Commit cleanly, open PR to `main`, verify CI green.
- [x] Live-wire `mac-18gb`, `windows-128gb`, and `wsl-94gb` (PQC Python on Windows, symmetric `goal-first-trillion` links/hooks, watchers/crons, real PQC CoD round-trip, live `--machine-pick` / `--machine-run` verification).
