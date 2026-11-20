2026-11-20-11-contract-drop-internals
# Task: the contract stops explaining the context system and names the folders instead

- lane: now
- branch: `feat/contract-drop-internals`
- status: implementing
- plan: `.agents/plans/2026-11-20-11-contract-drop-internals.md`
- scope: `AGENTS.md`, `.agents/canonical/AGENTS.md`, `scripts/test-pqc-dist.sh`,
  `src/context/engine.py`
- objective: An agent reading `AGENTS.md` should learn to call one command and which `.agents/` folders
  hold the record — not how the context system is built, and certainly not about a vector store that
  was deleted on 2026-11-12.

## Findings that shape the work

- Lines 23-26 describe a "four-part prime" and say "no embeddings, no vector store" — the operator's
  flagged excerpt. Lines 28-33 describe the background tuning pass, `provenance.harness`, and
  "never hand-edit retrieval constants".
- Line 15 tells an agent the call returns "the relevant corpus"; line 43 lists `wiki_graph_empty` as a
  degraded state; line 150 writes `.agents/{rag,audit,canonical}/`.
- `AGENTS.md` is `uchg` 444 — the write is refused until unlocked.
- The suite pins two of the sentences being removed (`:1414`, `:1416`), so they need repointing to the
  rule rather than deleting.
- Found while reading: `src/context/engine.py:7642-7643` looks for `src/rag/master-surfaces.json`,
  which has not existed since the engine moved to `src/context/`.

## Next action

T1: unlock and rewrite the section.
