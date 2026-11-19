2026-11-14-22-branch-materialization-latest
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
  Windows — established by `for-each-