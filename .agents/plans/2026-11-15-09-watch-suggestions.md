---
plan_format: ainish/plan/v1
slug: watch-suggestions
date: 2026-11-15
status: done
branch: feat/watch-suggestions
worktree: /Users/nbiish/code/watch-suggestions
task_record: .agents/tasks/2026-11-15-09-watch-suggestions.md
operator: question-me
---

# Plan: the four open suggestions on background sync

## 1. Problem

Four follow-ups were recorded after the ssh-transport fix: (1) loopback ssh is load-bearing but only
probed at install, so a later failure reads like a repo problem; (2) the plist records whatever
`bin/ainish-coder` was used to install, including a worktree path that dies when the worktree is
removed; (3) `--auto-commit` floods history with `wip(<machine>)` commits; (4) the watcher polls when
the host could watch file events instead.

## 2. Anchor Facts

- `_mw_cli` (`src/machine_watch.sh:200`) returns the path of the script's own checkout, so installing
  from a worktree writes the worktree's path — established by reading it, and observed live when the
  log filled with `no such file or directory: .../watch-ssh-transport/bin/ainish-coder`.
- `_mw_cycle_via_ssh` failures log only `ssh cycle failed` plus raw output (`:657`), so an expired key
  is indistinguishable from a peer problem.
- Fast-forward decisions use `merge-base --is-ancestor` on SHAs (`:192`, `:195`) and `--latest`
  attributes branches by SHA (`:324`). **Rewriting history therefore breaks core logic.**
- History holds 6 `wip(<machine>)` commits interleaved with real ones — established by
  `git log --oneline | grep -c 'wip('` in the target repo.
- `fswatch` is absent on this host; the plan that shipped the watcher explicitly rejected a
  mandatory dependency on it.

## 3. Plan

### Goals

- A broken loopback ssh is diagnosed as such, with the exact fix, on the first failing cycle.
- Installing from a worktree records a path that survives worktree removal.
- `wip` commits are informative rather than noise, with no history rewrite.
- File-event watching is used *when available*, with polling unchanged as the fallback.

### Non-goals

- **No history rewriting.** Squashing is rejected (see §4.3) because SHAs are load-bearing.
- No mandatory new dependency; `fswatch` stays optional.
- No change to sync semantics, the dirty-peer refusal, or the lock/backoff rules.

### Constraints and invariants

- Additive and reversible; nothing moves a peer that is dirty.
- Every new diagnosis names the command that fixes it.
- The gate stays green (currently 29/29 watch, 60/60 sync).

### Proposed architecture

```
install ──► resolve_stable_cli ──► plist records the MAIN checkout's bin/ainish-coder
                                        └─ worktree detected via git-common-dir ≠ git-dir

cycle (ssh) ──► on failure: _mw_ssh_health ──► "ssh localhost broke: run ssh-copy-id localhost"
                                              (recorded in state; re-probed, never assumed)

loop ──► _mw_watch_mode ──► fswatch present? subscribe : poll
```

### Interfaces and data

- `--machine-watch --status` gains `ssh` health and the recorded CLI path.
- `watch.state` gains `ssh=ok|broken` and `cli=<path>`.
- `--machine-watch --event-watch|--poll` forces the watch mode; default `auto`.

### Files and symbols

- `src/machine_watch.sh` — `_mw_resolve_stable_cli`, `_mw_ssh_health`, `_mw_watch_mode`, richer
  `_mw_cycle_via_ssh` failure text, `--event-watch`/`--poll`, status fields.
- `src/machine_sync.sh` — `--auto-commit` message carries the changed paths (still one commit).
- `scripts/test-machine-watch.sh` — assertions for all four.
- `README.md`, `src/help.sh`, `llms.txt` — document them.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Squash `wip(...)` on push | Rewrites SHAs that `merge-base --is-ancestor` and `--latest` depend on; would break fast-forward and attribution (§4.3). |
| Refuse to install from a worktree | AGENTS.md *mandates* worktree work; refusing blocks the documented path. Resolve the stable path instead. |
| Require `fswatch` | Contradicts the shipped design and its portability goal. Optional, detected, never required. |
| Re-probe ssh every cycle | Adds an ssh round trip per cycle to a loop that already pays one. Probe on *failure* instead. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| `--auto-commit` message grows unbounded | Cap the path list (e.g. first 10 + "and N more") |
| fswatch emits storms | Debounce already exists; reuse it |
| Detecting a worktree breaks single-checkout installs | Only redirect when `git-common-dir` differs from `git-dir` |

## 4. Clarifications

### 4.1 Which CLI path the plist should record

- **Question:** Install from a worktree — record the worktree path or the main checkout's?
- **Options:** 1. (Recommended) resolve the main checkout via `git-common-dir`; 2. refuse; 3. record as-is.
- **Selected:** resolve the main checkout's `bin/ainish-coder`; fall back to the current path only when
  no stable checkout can be found, and say so.
- **Trade-off accepted:** the daemon runs the main checkout's code, not the worktree's in-progress edits.
- **asked:** resolved from code
- **resolved by:** `_mw_cli` + the observed dead-worktree failure.

### 4.2 When to re-probe ssh

- **Question:** Every cycle, or only on failure?
- **Options:** 1. (Recommended) on failure; 2. every cycle.
- **Selected:** on failure, recorded in state, with the fix named.
- **Trade-off accepted:** a broken key is discovered at the first failing cycle rather than pre-emptively.
- **asked:** resolved from code
- **resolved by:** an ssh round trip is already the dominant cost per cycle.

### 4.3 What to do about `wip(<machine>)` commits

- **Question:** The suggestion offered squashing on push, or a commit template. Which?
- **Options:** 1. (Recommended) make the message informative and **never** rewrite; 2. squash on push;
  3. leave as-is.
- **Selected:** option 1. The `wip` commit body lists the changed paths so `git log` is readable, and
  squashing is documented as refused, with the reason.
- **Trade-off accepted:** history keeps one commit per synced burst; it is now legible instead of noise.
- **asked:** resolved from code
- **resolved by:** `merge-base --is-ancestor` (`:192`) and `--latest` SHA attribution (`:324`) — a
  rewrite invalidates both, and would corrupt every peer's fast-forward state.

## 5. Todos

- [x] **T1** `_mw_resolve_stable_cli` — record the main checkout's CLI; handle the worktree case.
- [x] **T2** `_mw_ssh_health` + failure diagnosis naming `ssh-copy-id localhost`; record in state.
- [x] **T3** `--auto-commit` message lists changed paths (capped), still one commit; document why
  squashing is refused.
- [x] **T4** `_mw_watch_mode` + `--event-watch`/`--poll`; use `fswatch` when present, else poll.
- [x] **T5** Gate assertions for T1–T4.
- [x] **T6** Docs: `src/help.sh`, `README.md`, `llms.txt`.

## 6. Verification

- `bash scripts/test-machine-watch.sh` — 0 failures, new assertions included.
- `bash scripts/test-machine-sync.sh` — still 60/0.
- Live: reinstall, confirm the plist records the main checkout; `--status` shows ssh health.
- `git log` in a synced repo shows a `wip` body naming the changed files.
