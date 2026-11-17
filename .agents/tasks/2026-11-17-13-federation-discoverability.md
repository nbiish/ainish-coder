# Task: make federation discoverable to agents

- lane: now
- branch: `feat/federation-discoverability`
- status: implementing
- plan: `.agents/plans/2026-11-17-13-federation-discoverability.md`
- scope: `src/rag/rag.py`, `AGENTS.md`, `scripts/test-pqc-dist.sh`, `llms.txt`,
  `.agents/tasks/2026-11-15-09-watch-suggestions.md`
- objective: An agent following the mandatory workflow (`--context`, then `AGENTS.md`) must learn that
  cross-machine sync exists, or it will hand-roll the thing this repo already ships.

## Findings that shape the work

- `ainish-coder --help` names federation 25 times; **`ainish-rag --help` names it 0 times**, and
  `AGENTS.md` 0 times — measured with `grep -c`.
- `AGENTS.md` sits at **exactly 160 lines against a hard 160-line gate**
  (`scripts/test-pqc-dist.sh:866`), so the pointer row must be paid for with a prose trim, not by
  raising the gate. The gate exists so the contract is read whole in one sitting.
- The `ORIENT_PRIMER` is generated from the wiki vault, so it cannot carry hand-written guidance.
- `.agents/tasks/2026-11-15-09-watch-suggestions.md` still said `implementing` although its work
  merged in `e08333a`; `--context` orientation was advertising a finished task as active.

## Why this is not cosmetic

The operator's goal is that a future agent uses the federation tooling instead of rebuilding it. An
undocumented-in-the-right-place capability is indistinguishable from a missing one to an agent that
only reads the contract and `--help`.
