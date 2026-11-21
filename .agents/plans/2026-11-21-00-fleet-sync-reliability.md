---
plan_format: ainish/plan/v1
slug: fleet-sync-reliability
date: 2026-11-21
status: ready
branch: feat/fleet-sync-reliability
worktree: ~/code/ainish-coder
task_record: .agents/tasks/2026-11-21-00-fleet-sync-reliability.md
operator: operator
---

# Plan: stop the sync watcher from interrupting work and losing repos

## 1. Problem

The background sync watcher is supposed to make several machines behave as one without anyone
thinking about it. Instead it has become an active hazard: it commits work while an agent is still
writing it, it holds the git index lock during ordinary commits, and when one repository fails it
retries that repository forever while silently starving every other repo. The operator cannot trust
it, and today it cost real work and real time.

This is the blocker under everything else. A fleet that claims success while dropping repositories
cannot run a business unattended.

## 2. Anchor Facts

Every fact below was verified in this session, from the log, the source, or a live run.

- **The watcher is losing far more than it wins.** `~/.config/ainish-coder/watch.log` holds
  **45** `Z ok:` lines and **79** `Z failed:` lines — established from `grep -c`.
- **One failing repo starves the rest.** the `local-router` checkout has been
  retrying continuously (attempts 51–55 within 11 minutes). During that window
  the `goal-first-trillion` checkout was **not synced at all** — its last
  success is `2026-11-21T00:10:09Z` — established from the log timeline.
- **The same repo succeeds when run by hand.** A manual
  `ainish-coder --machine-sync --kind windows --both --ff-peers` in `local-router` completed without
  a fetch error (only `smoke: … unverified`), so the repo and the peer are fine; the failure is in
  the watcher's invocation path — established by running it.
- **The logged failure mode is a delegated-cycle failure, not a git failure.**
  `2026-11-21T00:29:40Z failed: … (attempt 54)` is followed by `ssh cycle failed` with no `fatal:`
  line. The `_ms_peer_tmp` collision error
  (a `fatal:` line naming the peer temp bundle as 'does not appear to be a git repository') appears earlier in the log, before the concurrency fix — established from the log.
- **Loopback ssh works from an interactive shell** (`ssh localhost 'echo MW_OK'` → `OK`) and can
  read `local-router` over loopback (`git rev-parse` → `01e0e0c`). So "ssh cycle failed" is specific
  to the launchd context, not to ssh or the repo — established by running both.
- **`--auto-commit` committed a file that was still being written.** The `specialized-agents` skill
  appeared on `main` as `01c379c wip(Mac): synced by --auto-commit` mid-authoring, and a later
  attempt to commit hit `Unable to create '.git/index.lock': File exists` while the watcher held it
  — established from `git log` and the live failure.
- **`--auto-commit` authors as the operator.** Commits read the operator's configured identity rather
  than a machine identity — established from `git log -1 --format='%an <%ae>'`. `AGENTS.md` permits
  `Nanoboozhoo - embodied by {harness}` instead.
- **`watch.state` lies.** At `2026-11-21T00:32:29Z` it reported `repos=2 … failed=0 pid=66791` while
  the log recorded continuous failures and no process with that pid existed — established from
  `cat watch.state` vs `ps`.
- **The on-disk fix is newer than the running process.** The per-process bundle name
  (`c105a35`, 16:45) landed before the watcher started (16:46), yet the running cycle still produced
  the pre-fix error earlier in the log, meaning the watcher is not reliably executing current code —
  established from `git log --format=%ad` vs `ps -o lstart`.
- **A repo with unrelated peer history produces a permanent failure loop.** `ainish-coder`'s Mac and
  Windows checkouts have different root commits (`dda3a90` / `dc9d7e2`) and **zero** shared commits
  (`comm -12` over `git rev-list` → 0) — established earlier today and re-verified.

## 3. Plan

### Goals

- A failing repository **cannot** starve the others: every repo in `links.txt` gets a cycle attempt
  within a bounded interval, regardless of another repo's failure state.
- The watcher never mutates the working tree of a repository that has been edited in the last N
  seconds (an "edit quiet period"), so it cannot commit half-written files.
- The watcher never holds `index.lock` while another process commits: it uses the temp-index
  plumbing it already has (`_ms_wip_snapshot`) rather than `git add -A` on the real index.
- `watch.state` reflects reality: real pid, real failure count, per-repo last outcome.
- A repo that cannot ever converge (unrelated histories) is **quarantined** after bounded attempts
  instead of retrying forever.
- `--auto-commit` authors as `Nanoboozhoo - embodied by {machine}`.

### Non-goals

- Fixing the unrelated-history problem for `ainish-coder` itself. That is an operator decision
  (which history to keep) and stays out of this plan; the plan only stops it from poisoning the loop.
- Making sync faster. Correctness first; the loop's cost is dominated by ssh and is acceptable.
- Changing the bundle transport. It works when invoked correctly.

### Constraints and invariants

- Peers may run older ainish-coder versions; nothing may depend on the peer having this release.
- PowerShell is the Windows login shell: no `&&`, no `>/dev/null` in remote commands.
- The operator's git identity must never be used for machine-authored commits.
- Fail closed on claims: never report `failed=0` while failures occur.

### Proposed architecture

Four independent changes, each shippable alone:

```
  scheduler fairness      per-repo state machine, bounded backoff, quarantine
       |
  edit quiet period       mtime/porcelain check; skip cycles inside the window
       |
  lock-free commits       temp index (already exists) instead of `git add -A`
       |
  honest state file       atomic write: pid + started + per-repo outcome
```

### Interfaces and data

| Surface | Before | After |
|---|---|---|
| per-repo scheduling | one retry chain can monopolise the loop | every repo attempted each cycle; failing repo backs off independently |
| failed repo | retried forever | quarantined after `--quarantine-after N` (default 5) consecutive failures, retried on a long interval |
| `watch.state` | `failed=0` while failing | `pid`, `started`, `repos[]` with `last_outcome` and `consecutive_failures` |
| auto-commit author | operator identity | `Nanoboozhoo - embodied by {machine}` |

### Files and symbols

- `src/machine_watch.sh` — the cycle loop (per-repo iteration and backoff), `_mw_ssh_health`, the
  state writer, and the launchd unit that spawns the cycle.
- `src/machine_sync.sh` — the `--auto-commit` block (~L1095) for identity; `_ms_wip_snapshot` is the
  temp-index path to reuse.
- `.agents/plans/2026-11-21-00-local-router-sync.md` — companion plan for the repo-specific failure.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Just restart the watcher on a timer | Hides the starvation bug; a failing repo still blocks the rest |
| Drop local-router from `links.txt` | Removes the symptom, not the "one bad repo starves all" defect |
| Disable `--auto-commit` everywhere | Loses the only path that carries uncommitted work from an unattended machine |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Quarantine hides a repo that would have recovered | Long-interval retry, and `--status` must name quarantined repos prominently |
| Edit quiet period delays legitimate sync | Window is seconds, not minutes; a cycle skips, the next one catches up |
| Identity change breaks a consumer matching author | Grep for author assertions before merge; it is a contract requirement, not a preference |

## 4. Clarifications

- **"Interrupting our work" means two distinct mechanisms**, both confirmed: (a) committing files
  mid-authoring, (b) holding `index.lock`. The plan addresses both; it is not one bug.
  `asked: resolved from code`
- **Local-router itself is healthy.** A manual sync succeeds, so its plan is about the watcher's
  invocation path plus whatever the repo's own scripts do, not about the repository being broken.
  `asked: resolved from code`

## 5. Todos

- [ ] T1 Per-repo scheduling: a failing repo backs off independently and cannot delay others.
  Prove: force one repo to fail, confirm the other still cycles on schedule.
- [ ] T2 Quarantine after N consecutive failures with a long retry interval, surfaced in `--status`.
- [ ] T3 Edit quiet period: skip a repo edited within the window. Prove: touch a file, confirm no
  auto-commit for that cycle.
- [ ] T4 Replace the real-index `git add -A` in the auto-commit path with the temp-index plumbing, so
  a concurrent commit cannot collide on `index.lock`. Prove: two commits racing, no lock error.
- [ ] T5 `--auto-commit` authors as `Nanoboozhoo - embodied by {machine}`.
- [ ] T6 Atomic `watch.state` with real pid, `started`, per-repo outcome and failure count.
- [ ] T7 Prove the running daemon executes current code: log the source commit on startup and expose
  it in `--status`, so "fix merged but watcher stale" is visible instead of inferred.

## 6. Verification

- Force-fail one repo; the other must still sync within one interval. Scripted.
- `watch.state` `failed` count matches the log for the last cycle.
- `git log -1 --format='%an'` after an auto-commit is not the operator.
- No `index.lock` error while a watcher cycle and a manual commit overlap.
- `--status` names any quarantined repo.

## 7. Open Decisions

- **How long is the edit quiet period?** Needs a number; 10s is a guess, not a measurement.
- **Should quarantine notify?** A silent quarantine reproduces today's silent-starvation failure in
  a different form. Recommend it appear in `watch.state` and any digest.
