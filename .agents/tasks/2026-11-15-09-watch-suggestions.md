# Task: implement the four open background-sync suggestions

- lane: now
- branch: `feat/watch-suggestions`
- status: implementing
- plan: `.agents/plans/2026-11-15-09-watch-suggestions.md`
- scope: `src/machine_watch.sh`, `src/machine_sync.sh`, `src/help.sh`, `README.md`, `llms.txt`,
  `scripts/test-machine-watch.sh`
- objective: Close the four recorded follow-ups on background sync without weakening any invariant.

## What each item becomes, and why

1. **ssh re-probe** → probe on *failure*, not every cycle (an ssh round trip is already the dominant
   per-cycle cost), and name `ssh-copy-id localhost` in the diagnosis. Recorded in `watch.state`.
2. **worktree plist path** → resolve the *main* checkout via `git rev-common-dir`, because AGENTS.md
   mandates worktree work and refusing would block the documented path.
3. **`wip(...)` noise** → make the message informative (list the changed paths, capped). **Squashing
   is refused**: `merge-base --is-ancestor` and `--latest` attribution both depend on SHAs, so a
   rewrite would corrupt every peer's fast-forward state.
4. **poll → events** → use `fswatch` when it exists, fall back to polling unchanged. Stays optional;
   requiring it would contradict the shipped design and its portability goal.

## Constraints

No history rewriting. No new mandatory dependency. No change to the dirty-peer refusal, the lock, or
the backoff rules. Gates stay green (29/29 watch, 60/60 sync).
