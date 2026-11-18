2026-11-18-14-single-command-context
# Task: one command that reads the rules and keeps improving

- lane: now
- branch: `feat/single-command-context`
- status: implementing
- plan: `.agents/plans/2026-11-18-14-single-command-context.md`
- scope: `src/rag/rag.py`, `src/rag/context_harness.py`, `AGENTS.md`,
  `scripts/test-pqc-dist.sh`, `research/context-priming-master/10-single-command.md`
- objective: A single `ainish-rag --context` call must return the rules along with the prime, and must
  keep the repo's harness improving without a second command, so a deployed repo has one context entry
  point that gets better the more it is used.

## Findings that shape the work

- **`AGENTS.md` was not in the retrieval corpus at all.** `_graph_sources` enumerated the wiki vault and
  `.agents/{comms,memories,plans,suggestions,tasks}` only; measured `any('AGENTS' in n.path)` = `False`.
  The one command an agent is told to call could not answer "what are the rules here".
- **Routing can skip retrieval entirely**, and when it did, the prime contained zero mention of the
  contract. That is why the rules digest went into `orientation`, which is never skipped and costs no
  model call.
- **Learning was a second verb.** It is now spawned detached *after* the prime is assembled, so the
  answer is synchronous and improvement is not — resolving the earlier objection rather than ignoring it.
- The spawn is throttled by 6h **and** ≥1 new commit, because an unguarded spawn burns a model session
  on every call and the outcome signal needs commits to have anything to read.

## Deliberate deviation

This work was begun directly on `main` before the worktree was cut, which the contract's first
non-negotiable forbids. It is recorded here rather than hidden: the plan of record and this task exist
before the branch, and the changes move to the worktree before any commit.

## Next action

Move these changes into `feat/single-command-context`, re-run the suite there, then merge back oldest-first.
