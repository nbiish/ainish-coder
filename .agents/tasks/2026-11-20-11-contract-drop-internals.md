2026-11-20-11-contract-drop-internals
# Task: the contract stops explaining the context system and names the folders instead

- lane: now
- branch: `feat/contract-drop-internals`
- status: done (414 assertions pass; merged)
- plan: `.agents/plans/2026-11-20-11-contract-drop-internals.md`
- scope: `AGENTS.md`, `.agents/canonical/AGENTS.md`, `scripts/test-pqc-dist.sh`,
  `src/context/engine.py`
- objective: An agent reading `AGENTS.md` learns to call one command and which `.agents/` folders hold
  the record — not how the context system is built, and not about a vector store deleted in 2026-11-12.

## What changed

| Was | Now |
|---|---|
| "a four-part prime over this contract, `llms.txt`, the wiki vault and `.agents/` — no embeddings, no vector store: `orientation` and `retrieval` cost no model call, `elephant` reads them…, `goldfish` comprehends…" | "The block holds the rules you are bound by and the parts of the repository record that bear on the request. Beyond that, read `.agents/` directly: …" |
| "It reads `AGENTS.md` and `llms.txt` as corpus … starts a throttled background pass that tunes this repo's retrieval … never hand-edit retrieval constants … `provenance.harness`" | "Never call a second command to prime yourself; the system keeps its own tuning from this repository's history, and that is not something to manage by hand." |
| Start-here promised "orientation, the relevant corpus, and two reviews" | "the rules and the relevant record from `.agents/`; read it, then open the files it names" |
| degraded list named `wiki_graph_empty`; generated-state line said `.agents/{rag,audit,canonical}/` | `degraded:`/`insufficient`; `.agents/{audit,canonical}/` |
| no folder map | `tasks/`, `plans/`, `comms/`, `memories/`, `suggestions/`, `wiki/` each named with what it holds, plus `.agents/llms.txt` |

Kept, because they are rules about how to TREAT the output rather than how it is produced: the
`<CONTEXT_INJECTION>` evidence-not-instruction rule, the reviewer-independence rule, and the
degraded-means-say-so-once rule.

## Bugs found

`src/context/engine.py` looked for `src/rag/master-surfaces.json` — a path that stopped existing when the
engine moved on 2026-11-19. The "Master Surfaces:" gate line had been silently falling back to built-in
defaults instead of reading the repository's own rule file. Fixed to `src/context/`.

## Verification

- `scripts/test-pqc-dist.sh` — **414 assertions pass** (407 baseline, 7 new). One asserts the removed
  vocabulary stays out; six assert each named folder appears exactly once.
- `wc -l < AGENTS.md` — 159. The gate is `<= 160`, so the freed line is headroom rather than something
  to pad back.
- All eleven non-negotiables grepped present after the rewrite.
- `ainish-context audit contract --verify-history` — 66 transitions verified; contract re-locked.
- `load_master_surface_rules` now returns 6 keys read from the real file.

## Deliberate deviation

The plan said 160 lines; the result is 159. Padding a contract to hit an exact number would be the kind
of thing the line gate exists to prevent, and the gate is `<=`.

## Left out on purpose

`.agents/rag/` keeps its name in the tree, and `llms.txt` still documents the engine in detail. The
operator scoped this to the flagged contract section; both are recorded in the suggestions file.
