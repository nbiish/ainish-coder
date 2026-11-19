2026-11-14-23-machine-watch-daemon
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

## 3.