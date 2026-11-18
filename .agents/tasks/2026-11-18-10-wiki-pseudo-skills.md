2026-11-18-10-wiki-pseudo-skills
# Task: wiki markdown as pseudo-skills over the whole `.agents` corpus

- lane: now
- branch: `feat/wiki-pseudo-skills`
- status: implementing
- plan: `.agents/plans/2026-11-18-10-wiki-pseudo-skills.md`
- scope: `src/rag/rag.py`, `src/rag/context_harness.py`, `.gitignore`,
  `scripts/test-pqc-dist.sh`, `.agents/wiki/skills/`
- objective: The prime must read the whole `.agents` corpus and the research sources, and the learned
  skills abstracted from Harness² / the paper / both videos must live in the wiki as markdown
  pseudo-skills, so the wiki is both the corpus and the place improvement accumulates.

## Findings that shape the work

- **Corpus coverage is the defect.** `.agents/` holds 115 files, 10 are indexed; `research/` holds 30
  tracked files, 0 are indexed. The system cannot learn from material it never reads.
- **`.gitignore:189` is `/**/.agents/wiki/`**, so a learner writing into the wiki would be silently
  untracked and die on clone. Verified that negating the root dir fixes it while nested
  `src/rag/.agents/wiki/` stays ignored.
- **`generate_wiki` owns exactly seven filenames** and globs non-recursively, so `.agents/wiki/skills/`
  is a place the generator will never touch — which is what makes the operator's design work.
- **Scale is affordable**: 658 projected nodes, 216k pairwise comparisons, measured 41ms, cached on
  mtime so it is paid per corpus change rather than per query.
- All four sources are already captured verbatim under `research/context-priming-master/sources/`.

## Next action

T1: make the wiki trackable, then widen the corpus.
