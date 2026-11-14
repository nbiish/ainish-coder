---
plan_format: ainish/plan/v1
slug: machine-watch-daemon
date: 2026-11-14
status: implementing
branch: feat/machine-watch-daemon
worktree: /Users/nbiish/code/machine-watch-daemon
task_record: .agents/tasks/2026-11-14-23-machine-watch-daemon.md
operator: question-me
---

# Plan: `--machine-link --watch` — a background watcher that keeps federated repos current

## 1. Problem

Links currently fire on *commit*. The operator saves a file and nothing moves, because an
uncommitted edit is not a git object and there is no transport for it. The operator asked for the
opposite: run the link command once, and from then on a saved file shows up on the other machines
without thinking about commits, branches, or which copy is newest.

## 2. Anchor Facts

- No `fswatch` and no `inotifywait` on this Mac — established by `command -v`. Watchers must poll.
- `~/Library/LaunchAgents` is writable, so a user-level daemon installs without sudo.
- A saved-but-uncommitted file shows as `??` in `git status --porcelain` and does not cross today.
- `--auto-commit` already exists (`src/machine_sync.sh:431`) and commits the working tree before
  sending; the snapshot ref is a fallback. The watcher can reuse this proven path.
- `--branches`, `--linked-only`, `--quiet`, and `--all` already exist and are gate-tested (60/60).
- The existing hooks are `post-commit`/`post-merge`; they cannot see a save.

## 3. Plan

### Goals

- One command (`--machine-link --watch`) installs a per-user background watcher for every linked repo.
- A save propagates to a clean peer within seconds, with no operator action and no daemon restart.
- The watcher survives reboot and runs at login.
- Conflicts are surfaced, never auto-resolved.

### Non-goals

- No kernel file-event watcher (absent on this host); polling is the transport.
- No auto-merge of divergent histories — a merge is a decision, not a sync.
- No push to a Git remote; LAN-SSH only, same as everything else here.

### Constraints and invariants

- **Never move a dirty peer's tree.** Only fast-forward when the peer is clean and on our branch.
- **One sync cycle at a time.** A lock file prevents overlap; a stale lock is reclaimed by PID check.
- **Debounce.** A burst of saves becomes one commit, not twenty.
- **Bounded.** Every cycle has a timeout; a dead peer cannot wedge the watcher.
- **Loud.** A blocked peer is reported, not silently skipped.
- Failure of the watcher must never damage a repo.

### Proposed architecture

```
launchd / systemd  ──►  ainish-coder --machine-watch  (supervisor loop)
                              │
                              ├─ for each linked repo:
                              │     detect change (hash of `status --porcelain` + HEAD)
                              │     if changed: wait for quiescence (debounce)
                              │     ainish-coder --machine-sync <repo> --both --branches \
                              │                  --auto-commit --linked-only --quiet
                              │     (the proven path: commit, push, pull, materialise)
                              └─ sleep interval; repeat
```

### Interfaces and data

- `--machine-link DIR --peer NAME --watch` — link **and** install the watcher.
- `--machine-watch [--interval N] [--debounce N] [--once] [--foreground] [--verbose]` — run the loop.
- `--machine-watch --status` — is it installed, running, and what did the last cycle do.
- `--machine-watch --uninstall` — stop and remove the daemon (links stay).
- State: `~/.config/ainish-coder/watch.state` (last cycle, last error), `.git/ainish-watch.lock`.
- Daemon: `~/Library/LaunchAgents/ai.nanoboozhoo.ainish-machine-watch.plist` (macOS),
  `~/.config/systemd/user/ainish-machine-watch.service` (Linux).

### Files and symbols

- `src/machine_watch.sh` (new) — `machine_watch`, install/uninstall/status, plist + unit emitters.
- `src/machine_link.sh` — `--watch` flag hands off to the installer.
- `bin/ainish-coder` — dispatch `--machine-watch`.
- `src/help.sh`, `README.md`, `llms.txt` — document it.
- `scripts/test-machine-watch.sh` (new) — hermetic: debounce, one-commit-per-burst, dirty-peer
  refusal, lock, and `--once`.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| `fswatch`/`inotifywait` | Not installed; adding a dependency to a portable script is worse than a 2s poll. |
| Watch only `post-commit` (status quo) | Cannot see a save, which is exactly the ask. |
| `rsync` the tree | Carries ignored files, `.exe`, signing keys, and can overwrite a dirty peer. |
| Auto-merge diverged branches in the loop | Unreviewable; two lanes that meet must be a human decision. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Commit spam from repeated saves | Debounce to quiescence, then one commit per burst |
| Two machines commit at once → divergence | Report and stop; never auto-merge |
| Watcher overwrites uncommitted peer work | Peer is only moved when clean; otherwise reported |
| Two cycles overlap | Lock file with PID liveness check |
| Daemon dies silently | `--status` reads last-cycle timestamps; plist uses `KeepAlive` |
| Secrets leave via a save | Same as any commit: the repo's own ignore rules and the existing secret scan apply |

## 4. Clarifications

### 4.1 Trigger: hooks vs watcher

- **Question:** Earlier the operator chose hooks only; now asks for save-level sync.
- **Options:** 1. watcher daemon; 2. hooks only; 3. both.
- **Selected:** a watcher daemon, in addition to the hooks already installed.
- **Trade-off accepted:** a background process polls every few seconds; it is bounded and per-user.
- **asked:** operator
- **resolved by:** this request ("if I save a file; the files machines should update").

### 4.2 What "instantaneous" can mean

- **Question:** Can a save reach a peer's working tree instantly?
- **Options:** 1. (Recommended) poll ~2s, debounce ~1.5s → seconds, and only into a clean peer;
  2. claim instant and risk destroying a peer's unsaved work.
- **Selected:** ~2s poll with debounce; a dirty peer is reported, never overwritten.
- **Trade-off accepted:** not literally instant, and a busy peer blocks until it is clean.
- **asked:** resolved from code
- **resolved by:** no `fswatch`/`inotifywait` available; and overwriting a dirty tree is data loss.

## 5. Todos

- [x] **T1** `src/machine_watch.sh`: change detection, debounce, lock, one-cycle sync via the
  existing `--machine-sync --both --branches --auto-commit --linked-only --quiet` path.
- [x] **T2** Install/uninstall/status: launchd plist (macOS) and systemd user unit (Linux).
- [x] **T3** `--machine-link --watch` and `bin/ainish-coder` dispatch.
- [x] **T4** `scripts/test-machine-watch.sh`: debounce coalesces a burst into one commit; a dirty
  peer is refused; the lock prevents overlap; `--once` runs a single cycle.
- [x] **T5** Docs in `src/help.sh`, `README.md`, `llms.txt`; state the poll interval honestly.
- [ ] **T6** Live install on this Mac and prove a save reaches Windows without a command.
  - status: **code done, install blocked on macOS TCC.** The foreground loop and the manual cycle both
    sync a save to Windows successfully (`de0b3be`, `84ebc3c` verified on both machines). The launchd
    agent cannot: TCC denies a launchd-spawned process read access to the external volume the repo
    lives on (`Operation not permitted` on a repo that is readable from a terminal). The installer now
    detects this and fails with the fix rather than claiming success. See §7.

## 6. Verification

- `bash scripts/test-machine-watch.sh` — 0 failures.
- `bash scripts/test-machine-sync.sh` — still 60/0.
- Live: install on the Mac, save a file, observe it on Windows within one interval.
- Live: `--machine-watch --status` reports the last cycle time and result.
- `git log main..feat/machine-watch-daemon` empty after merge; worktree removed.

## 7. Open Decisions

- **macOS TCC and external volumes.** The launchd agent cannot read a repo on `the external-volume mount point`;
  a launchd-spawned process gets `Operation not permitted`. Verified by a minimal probe agent that
  read an internal-disk repo successfully and the external-volume repo with a permission error, in the
  same process. Three fixes, in order of preference:
  1. Grant Full Disk Access to `/bin/bash` (System Settings → Privacy & Security → Full Disk Access).
  2. Move the repository to the internal disk — verified working end to end.
  3. Run `--machine-watch --foreground` from a terminal, which already has access.
  The installer refuses to claim success until one of these is done, and names the fix.

- **A failed sync must not be recorded as synced.** Found live: the first implementation wrote the
  change fingerprint even on failure, so a transient error marked the save "handled" and it was never
  retried — a silent data-loss path. Fixed (fingerprint on success only) and pinned by gate §8.
