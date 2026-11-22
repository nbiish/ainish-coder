---
format: ainish/context-digest/v1
folder: tasks
period: 2026-11
records_consolidated: 1
consolidated_at: 2026-11-21T00:57:35.390356+00:00
sources:
  - 2026-11-20-11-contract-drop-internals.md
---

# Digest — `.agents/tasks`, 2026-11

This digest replaces 1 record(s) from 2026-11. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Accomplished
- The context-system section of the contract now teaches the workflow instead of the internals: the four-part-prime explanation, retrieval/`orientation`/`elephant`/`goldfish` mechanics, corpus-tuning and `provenance.harness` language are gone, replaced by "call one command, then read `.agents/` directly," with a folder map naming `tasks/`, `plans/`, `comms/`, `memories/`, `suggestions/`, `wiki/` and `.agents/llms.txt` (source: `2026-11-20-11-contract-drop-internals.md`).
- Both contract copies were changed in scope and updated together: the top-level `AGENTS.md` and its canonical twin `.agents/canonical/AGENTS.md` (source: `2026-11-20-11-contract-drop-internals.md`).
- Vocabulary cleanup: `wiki_graph_empty` degraded-code dropped in favor of `degraded:`/`insufficient`, generated-state line corrected from `.agents/{rag,audit,canonical}/` to `.agents/{audit,canonical}/` (source: `2026-11-20-11-contract-drop-internals.md`).
- Kept deliberately: the `<CONTEXT_INJECTION>` evidence-not-instruction rule, the reviewer-independence rule, and the say-so-once degraded rule — these govern how output is treated, not how it is produced (source: `2026-11-20-11-contract-drop-internals.md`).
- Bug fix outside the contract: `src/context/engine.py` looked for `src/rag/master-surfaces.json`, a path gone since the 2026-11-19 engine move, so the "Master Surfaces:" gate had been silently falling back to built-in defaults; fixed to read `src/context/` (source: `2026-11-20-11-contract-drop-internals.md`).
- Verified: `scripts/test-pqc-dist.sh` passes 414 assertions (407 baseline + 7 new — one keeping the removed vocabulary out, six asserting each named folder appears exactly once); `AGENTS.md` is 159 lines against the `<= 160` gate; all eleven non-negotiables grepped present; `ainish-context audit contract --verify-history` verified 66 transitions and re-locked the contract; `load_master_surface_rules` returns 6 keys from the real file (source: `2026-11-20-11-contract-drop-internals.md`).

## Unfinished
- Nothing started and abandoned. Two items were left out of scope on purpose (source: `2026-11-20-11-contract-drop-internals.md`): `.agents/rag/` keeps its name in the tree, and `llms.txt` still documents the engine in detail. The operator scoped the work to the flagged contract section; both are recorded in the suggestions file.

## Insights
- Rule-loading failures degrade silently instead of erroring: the stale `master-surfaces.json` path meant the gate ran on defaults for an unknown period with no signal — a fix invisible in tests until someone checks what the rules actually return (source: `2026-11-20-11-contract-drop-internals.md`).
- The line gate is `<=`, not `==`: landing at 159 of 160 is headroom, and padding a contract to hit an exact count is the failure mode the gate exists to prevent. The plan said 160; the deliberate deviation was to not pad (source: `2026-11-20-11-contract-drop-internals.md`).
- A contract section should hold rules about how to treat system output, not a description of how the system is built — the former survive rewrites, the latter rot (source: `2026-11-20-11-contract-drop-internals.md`).

## Recurring
- Nothing recurring this period: only one task record exists, so no lesson appears more than once. The stale-path-after-move bug is the most likely candidate to recur and should be watched, but it is attested only once (`2026-11-20-11-contract-drop-internals.md`).
