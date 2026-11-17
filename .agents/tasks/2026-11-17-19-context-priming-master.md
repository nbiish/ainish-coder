2026-11-17-19-context-priming-master
# Task: a per-repo self-improving context harness inside `ainish-rag --context`

- lane: next
- branch: `feat/context-priming-master`
- status: ready
- plan: `.agents/plans/2026-11-17-19-context-priming-master.md`
- scope: `src/rag/rag.py`, `bin/ainish-coder`, `src/skills_selection.sh`, `src/deploy_skills.sh`,
  `scripts/test-pqc-dist.sh`, `.agents/context-harness/`, `research/context-priming-master/`
- objective: `--context` learns per repo. A `PrimeProfile` plus learner-authored skill files, produced
  by a contrastive propose/probe/gate loop seeded at `--rules`, so a deployed repo's prime improves from
  its own accumulated experience instead of shipping one frozen hand-tuned configuration everywhere.

## Findings that shape the work

- **Research is complete and is the real deliverable of this pass**:
  `research/context-priming-master/` — 8 documents, ~1,900 lines, plus raw sources (arXiv 2610.14224,
  both video transcripts, harness2 read at source level). `README.md` is the entry point.
- **The paper's worst result is the design's hardest constraint**: refining a harness without a
  reference execution and a library *degrades* performance (Code 73.4 → 63.2). Generation 0 is
  therefore frozen and mandatory, not a nicety — see `05-design.md` and R1.
- **The video's round 1 result is the honesty test**: an elegant recursive harness *matched* a frozen
  three-tool harness exactly. `KEEP_BASE` must be a first-class recorded outcome, because it may be the
  common one.
- **The operator widened the surface** from numbers-only to harness²-style skill files and scripts
  (`04`→`05b`). The consequence is blunter than it looks: `.agents/skills/` is standing prompt surface
  for *every* agent harness in a repo (`.agents/skills/llms.txt`), so learned skills are **staged**
  under `.agents/context-harness/skills/` and promoted only by explicit operator action. A learned
  skill's reach is therefore smaller than harness²'s — recorded as a deliberate divergence, since we
  have a prime that can only point rather than a runtime that can dispatch.
- **`src/deploy_skills.sh:181` sweeps target skill dirs absent from source** only when a selection
  entry exists. A promoted `learned-*` pack survives today by accident; that needs `_skill_learned`
  beside `_skill_mandatory` before the feature ships (R13).
- **`--context` has no learnable state at all**: every ranking constant is a module-level literal
  (`rag.py:3489`, `:3591–3594`, `:3787`, `:3857`) chosen by hand for this repository.

## Constraints that bound the work

- `AGENTS.md` is at its hard 160-line cap (`scripts/test-pqc-dist.sh:722`, `:878`). This work adds
  nothing to it.
- `src/rag/rag.py` is stdlib-only. No embeddings, no vector store, no third-party dependency.
- `.agents/rag/` is gitignored; learned state goes to the tracked `.agents/context-harness/`.
- No new injection section — learned content rides inside the existing retrieval share, and provenance
  carries the metadata.
- A `--context` call must never block the task, so learning is a separate verb.

## Next action

Phase 0 (todo T1): a throwaway script rendering retrieval for 8 real tasks under base/wide/narrow
profiles, computing five signals, answering whether they separate anything. It can stop the project.
Do not start Phase 1 until it has.
