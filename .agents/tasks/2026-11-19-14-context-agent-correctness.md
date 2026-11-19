2026-11-19-14-context-agent-correctness
# Task: make `ainish-coder --context` a real self-improving context agent

- lane: now
- branch: `feat/context-agent-correctness`
- status: implementing
- plan: `.agents/plans/2026-11-19-14-context-agent-correctness.md`
- scope: `bin/ainish-coder`, `bin/ainish-rag`, `AGENTS.md`, `src/rag/rag.py`,
  `src/rag/context_harness.py`, `scripts/test-pqc-dist.sh`, `llms.txt`, `.agents/wiki/`,
  `research/context-priming-master/probe_corpus.py`
- objective: Make `ainish-coder --context "<input>"` the single entry point any agent harness calls
  after reading `AGENTS.md`, backed by a corpus it actually indexes, a gate that can actually accept,
  a wiki it can actually edit, and one self-editing skill surface separate from `.agents/skills/`.

## Findings that shape the work

- **The whole-corpus fix never took effect.** `GRAPH_MAX_ARTIFACTS = 0` means unlimited, but
  `BASE_PROFILE` still ships 2, and `run_context_command` always overlays it. Measured 60 of 167
  corpus files indexed, 2 per coordination folder.
- **The gate cannot accept.** Commit-subject overlap reaches 5 of 10 real task objectives, and the
  spawned learner passes the raw query whose commit does not yet exist. One live pass was refused
  during this session's first context call.
- **No generation exists on this repo**, so nothing has a baseline to contrast against.
- **The wiki cannot be refreshed**, so the agent cannot edit the corpus it learns from.
- **`weights` is validated and reported but never read**, and in-bounds zeros are replaced by `or`.
- **Two disjoint skill surfaces** mean neither is authoritative.
- **The contract claims a reviewer refusal that `plan_reviewer_model` implements and nobody calls.**

## Next action

T1: add `--context` to `bin/ainish-coder` and update the contract's two references.
