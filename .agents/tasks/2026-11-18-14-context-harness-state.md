2026-11-18-14-context-harness-state
# Task: bound the context-harness state directory

- lane: now
- branch: `fix/context-harness-state`
- status: done
- plan: `.agents/plans/2026-11-18-14-context-harness-state.md`
- scope: `src/rag/context_harness.py`, `src/rag/rag.py`, `.agents/context-harness/.gitignore`,
  `scripts/test-pqc-dist.sh`
- objective: A learning loop intended to run for the life of a repository must not grow without limit.
  Cap the evidence trees and the refusal record, and separate per-machine traces from learned state that
  must survive a clone.

## Findings that shape the work

- `work/<stamp>/` was written once per pass and never removed; `rejected/<stamp>.md` was appended on
  every refusal and never capped. Both are unbounded.
- `.agents/context-harness/` is not gitignored, so everything written there was a commit candidate —
  including per-machine operational traces that should not diverge between machines.
- The first attempt at the fix placed the prune call **after** `_harness_evidence_tree`, which would have
  made the newest evidence the first thing eligible for removal. Moved to the start of the pass.

## Note on process

The plan gate refused the commit for this branch until this plan existed, which is the gate working as
intended — recorded here rather than bypassed with `AINISH_SKIP_PLAN_CHECK`.

## Next action

Commit, merge, remove the worktree.
