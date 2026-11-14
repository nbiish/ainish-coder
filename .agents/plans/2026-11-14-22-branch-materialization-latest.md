---
plan_format: ainish/plan/v1
slug: branch-materialization-and-latest
date: 2026-11-14
status: implementing
branch: feat/branch-materialization-latest
worktree: /Users/nbiish/code/branch-materialization-latest
task_record: .agents/tasks/2026-11-14-22-branch-materialization-latest.md
operator: question-me
---

# Plan: every branch present on every machine, and one view that says what is newest

## 1. Problem

`--machine-sync` delivers every branch as `refs/remotes/<machine>/*`, but a remote-tracking ref is not
a branch you can work on. After a sync the Mac holds six local branches while Windows still holds only
`main`, so "sync all branches" is not true in the sense the operator means: switching machines means
switching to a peer ref, or re-creating branches by hand. Separately, nothing answers "which copy is
the latest" — `--status` reports only what this machine already knows, with no network, so the one
question that decides where to work is the one not answered.

## 2. Anchor Facts

- Mac holds 6 local branches (`docs/hub-consolidation`, `docs/multi-machine-orchestration`, `main`,
  `preserve/mac-3c87fac`, `preserve/mac-dirty-tree`, `snapshot/oct31`); Windows held only `main`
  locally — established by `for-each-ref refs/heads` on each side.
- After a pull, the Mac knows `refs/remotes/windows-128gb/main = 555b46e` and nothing else from
  Windows — established by `for-each-ref refs/remotes/windows-128gb/`.
- Mac `main` (`e4f845d`) and Windows `main` (`555b46e`) have **no common ancestor** — established by
  `git merge-base main windows-128gb/main` printing nothing.
- The newest commit anywhere in this repo is `preserve/mac-dirty-tree` (2026-11-14 16:34); the newest
  commit on a real shared line of work is `origin/main` (2026-11-08 10:31) — established by sorting
  every ref by `committerdate`.
- Windows runs `ainish-coder` at `1bd8865`, which predates `--machine-link` — established by
  `git log -1` on `D:/Code/ainish-coder`. **Any peer-side mutation must therefore use plain git
  plumbing over ssh, never the peer's CLI.**
- `--status` is documented as "no network, no transfer" (`src/machine_sync.sh`), so it cannot answer a
  cross-machine question by construction.
- The baseline gate is green: `scripts/test-machine-sync.sh` 48 passed / 0 failed.

## 3. Plan

### Goals

- After a sync, every branch the sender has exists as a **local branch** on the receiver, so a machine
  can be worked on directly after switching to it.
- One command answers "which machine holds the newest commit for this branch".
- Neither behaviour can destroy local work: an existing branch is never moved or overwritten.

### Non-goals

- Not merging unrelated histories. Materialising `main` on a machine that already has an unrelated
  `main` is refused and reported — the base-history decision stays with the operator.
- Not a daemon; the existing hook stays push-only and gains the new flag.
- Not pushing to a Git remote.

### Constraints and invariants

- **Additive only.** `git branch <name> <ref>` when `<name>` is absent. When it exists, compare and
  report; never `-f`, never `update-ref refs/heads/...`.
- **No peer-CLI dependency.** Branch creation on a peer runs as plain `git -C … branch …` over ssh,
  because the peer may run an older `ainish-coder`.
- **Bounded probes.** Every peer call keeps `BatchMode`/`ConnectTimeout`; `--latest` must not hang on
  an unreachable machine.
- A branch that exists and differs is reported as `diverged`, never silently skipped.

### Proposed architecture

```
after refs land (either direction):
  refs/remotes/<src>/<branch>  ──►  refs/heads/<branch>      (only if absent)

--latest:
  local branches ∪ peer branches (over ssh, bounded)
        │
        └─► per branch: newest tip by committerdate, and which machines hold it
```

### Interfaces and data

- `--machine-sync … --branches` — materialise local branches from the delivered refs, both directions.
- `--machine-sync … --latest` — cross-machine report; per branch: newest sha, date, subject, holders.
- `--machine-sync … --latest --json` — `ainish-coder/machine-latest/v1`.
- Exit codes unchanged: 0 all peers ok, 1 a peer failed.

### Files and symbols

- `src/machine_sync.sh` — `_ms_materialize_branches`, `_ms_latest`, flags, help.
- `src/machine_link.sh` — the hook gains `--branches` so a linked repo keeps every branch current.
- `scripts/test-machine-sync.sh` — assertions for materialisation, non-overwrite, and `--latest`.
- `src/help.sh`, `README.md`, `llms.txt` — document both.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Force-update peer branches to match ours | Destroys the peer's local work; the exact failure the tool exists to prevent. |
| Make the peer run its own `ainish-coder --pull` | Windows' CLI predates the feature; a version skew would silently do nothing. |
| Rely on `refs/remotes/*` being "good enough" | It is not a branch you can check out and work on; the operator asked for branches. |
| Answer `--latest` from cached refs only | Those refs are stale by definition — the question is what is newest *now*. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Materialising creates a branch that shadows unrelated work | Refuse when the name exists; report `diverged` with both shas. |
| `--latest` slows down with many branches | One bounded `for-each-ref` per peer, not one call per branch. |
| Hook cost grows | `--branches` is one extra `branch` call per absent branch, only on commit. |

## 4. Clarifications

### 4.1 What "sync all branches" means

- **Question:** Should peer branches become local branches, or stay remote-tracking refs?
- **Options:** 1. (Recommended) local branches where absent, never overwriting; 2. keep refs only.
- **Selected:** materialise local branches where absent; existing ones are compared and reported.
- **Trade-off accepted:** the receiver gains local branches it did not create, so `git branch` output
  grows; this is what makes a machine directly workable after switching.
- **asked:** resolved from the operator's request ("main and all branches to sync across machines")
- **resolved by:** the request, plus the observed state (Windows had only `main`).

### 4.2 Unrelated `main` on two machines

- **Question:** Mac `main` and Windows `main` share no ancestor; what should `--branches` do?
- **Options:** 1. (Recommended) refuse and report both tips; 2. overwrite one; 3. rename the peer's.
- **Selected:** refuse, report `diverged` with both shas and a one-line remedy.
- **Trade-off accepted:** `main` stays unreconciled until the base-history merge is done; that is a
  deliberate operator decision, not something a sync flag may take.
- **asked:** resolved from code
- **resolved by:** `git merge-base main windows-128gb/main` returns nothing.

## 5. Todos

- [x] **T1** Add `_ms_materialize_branches` — create absent local branches from delivered refs, both
  directions, plain git over ssh for peers.
  - from: §4.1 | done when: a peer with only `main` gains the sender's other branches
- [x] **T2** Report existing branches as same/ahead/behind/diverged; never move one.
  - from: §4.2 | done when: an unrelated `main` is refused with both shas
- [x] **T3** Add `--branches` and wire it into the `--machine-link` hook.
  - from: §3 | done when: a commit on a linked repo materialises branches on the peer
- [x] **T4** Add `--latest` (+ `--json`) — per branch, newest tip and which machines hold it.
  - from: §3 | done when: the report names the newest machine for every branch
- [x] **T5** Extend the gate; keep 0 failures.
  - from: §3 | done when: new assertions pass and nothing regressed
- [x] **T6** Docs: `src/help.sh`, `README.md`, `llms.txt`.
  - from: §3 | done when: flags documented with examples

## 6. Verification

- `bash scripts/test-machine-sync.sh` — 0 failures (baseline 48/0, no regression).
- Hermetic: peer with one branch gains the others; an existing diverged branch is untouched.
- Live: `--branches` against `windows-128gb`; every Mac branch appears as a local branch there.
- Live: `--latest` names the newest machine per branch without hanging on an unreachable peer.
- `git log main..feat/branch-materialization-latest` empty after merge; worktree removed.
