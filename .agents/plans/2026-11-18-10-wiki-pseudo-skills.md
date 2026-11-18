---
plan_format: ainish/plan/v1
slug: wiki-pseudo-skills
date: 2026-11-18
status: done
branch: feat/wiki-pseudo-skills
worktree: /Users/nbiish/code/wiki-pseudo-skills
task_record: .agents/tasks/2026-11-18-10-wiki-pseudo-skills.md
operator: direct-instruction
---

# Plan: wiki markdown as pseudo-skills, over the whole `.agents` corpus

## 1. Problem

The context system reads a small sample of what this repository knows. Measured: `.agents/` holds **115
files** and only **10** are indexed (the newest two per coordination folder), the 25 research files are
not indexed at all, and the wiki is capped at its newest 8 pages. So an agent asking about work from last
week, or about the research this system is built on, gets nothing — and the learning loop cannot help,
because the material it would learn from is not in the corpus.

The operator's direction: the learned, continuously-improving skills should live **in the wiki as markdown
pseudo-skills**, abstracted from the four research sources (Harness², the paper, both videos), so the wiki
is both the corpus the prime reads *and* the place improvement accumulates.

## 2. Anchor Facts

- `.agents/` census: comms 17, memories 19, plans 24, suggestions 14, tasks 41, wiki 11, templates 5,
  skills 32 files. `research/` holds 30 tracked files.
- Indexed today: **52 nodes** total — `wiki` 21, `map` 1, `contract` 20, and 2 per coordination folder.
  `GRAPH_MAX_ARTIFACTS = 2`, `GRAPH_MAX_WIKI_PAGES = 8`.
- Full indexing projects to **~658 section nodes** and **216,153** pairwise edge comparisons; measured at
  **41ms**, and the graph is cached on mtime+settings, so this is paid once per change, not per query.
- **`.gitignore:189` is `/**/.agents/wiki/`** — anything written into the wiki by a learner would be
  gitignored and die on clone. Verified: negating the root dir (`!/.agents/wiki/`) makes
  `.agents/wiki/skills/learned-x.md` **trackable** while `src/rag/.agents/wiki/` stays **ignored**.
- `generate_wiki` owns exactly seven filenames: `README.md`, `01-architecture.md` … `06-marketing-and-positioning.md`.
  It does **not** glob subdirectories, and it refuses to run at all when vault pages exist (`VAULT_TAG`).
- `.agents/wiki/*.md` globbing is **non-recursive** at all five call sites, so a subdirectory is invisible
  to every current reader — a learner can write there without colliding with the generator.
- Research sources are already captured verbatim: arXiv HTML (1,723 lines), both YouTube transcripts
  (501 + 197 lines), and the harness² implementation read at source level in `02-harness2-mechanics.md`.

## 3. Plan

### Goals

- Index **the whole `.agents` corpus** and `research/`, not a sample: every coordination file, every
  template, every wiki page, every research source.
- Make `.agents/wiki/skills/` the home of learned pseudo-skills — markdown pages with frontmatter that
  the retrieval graph and the learner both understand.
- Abstract reusable skills **from the four sources** into that directory, so the system's own learning is
  grounded in the research rather than invented.
- Keep the prime fast and the budget honest: a much larger corpus must not mean a much larger prime.

### Non-goals

- Embedding or vector search — the no-dependency property is load-bearing on every host this ships to.
- Writing into the seven generator-owned wiki pages; they are regenerated and would clobber learner text.
- Auto-promoting pseudo-skills into `.agents/skills/`; promotion stays operator-only (see `05b`).

### Constraints and invariants

- `--context` with a corpus this size must still return quickly; the graph cache must key on the corpus
  definition so a widened source set invalidates it.
- Indexing everything must not make retrieval *worse*: a 658-node graph with naive scoring would let
  stale coordination files outrank the wiki. Recency and kind weighting must be explicit.
- `AGENTS.md` stays at 160 lines.
- Anything the learner writes must survive a clone, or the wiki must say it does not.

### Proposed architecture

```
.agents/                         research/
  comms/ memories/ plans/          context-priming-master/
  suggestions/ tasks/               01-source-extraction.md
  templates/                        02-harness2-mechanics.md
  wiki/                             08-phase0-findings.md
    01..06 (generator-owned)        sources/arxiv-*.md
    README.md (+ ledger)            sources/video1-*.txt
    skills/            <-- NEW: learned pseudo-skills, tracked
      learned-<name>.md
                                 \        /
                                  \      /
                            _graph_sources()
                                  |
                        section-split nodes
                                  |
                    prime (bounded by the same budget)
```

A **pseudo-skill** is a markdown file with Obsidian-compatible frontmatter:

```markdown
---
title: Reconcile conflicting task records
tags: [ainish/wiki/skill, ainish/learned]
trigger: [reconcile, status, drift]
evidence: ".agents/tasks/2026-11-17-13-federation-discoverability.md"
generation: 3
---
```

It is not auto-loaded by any agent harness (unlike `.agents/skills/`); it reaches a model only through
the prime, and it is graded by the same deterministic gate as the rest of the harness.

### Interfaces and data

- `_graph_sources` gains: all coordination files (not just the newest two), `templates/`, `research/`,
  and `.agents/wiki/skills/**/*.md`.
- `GRAPH_ARTIFACT_DIRS` keeps its name; `GRAPH_MAX_ARTIFACTS` becomes a *per-folder* cap with a much
  larger default, or 0 meaning unlimited.
- New `KIND_WEIGHTS` so a comms line from last month cannot outrank a wiki section.
- `context_harness.skill_*` gains wiki-pseudo-skill read/write alongside the staged `skills/` tree.

### Files and symbols

- `src/rag/rag.py` — `_graph_sources`, `build_wiki_graph`, `GRAPH_*` constants, kind weighting in
  `graph_retrieve`.
- `src/rag/context_harness.py` — pseudo-skill paths under the wiki, frontmatter validation.
- `.gitignore` — negate the root wiki dir so learned pseudo-skills are trackable.
- `scripts/test-pqc-dist.sh` — assertions for corpus coverage, tracking, and kind weighting.
- `.agents/wiki/skills/` — the abstracted pseudo-skills themselves.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Put pseudo-skills in `.agents/skills/` | Auto-discovered by every harness as standing prompt surface; a self-improving loop must not silently enlarge it |
| Keep the 2-per-folder cap and add only research | Leaves 105 of 115 coordination files invisible; the operator asked for comprehensive review |
| Index everything into one flat node list | A stale comms line would compete with the wiki; needs explicit kind weighting |
| Write learned skills into the seven generated wiki pages | The generator owns those filenames and would overwrite them |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| A larger corpus makes the prime worse, not better | Kind weighting + recency; measured before/after on a fixed probe set |
| Learned wiki files silently gitignored | Verified negation; assertion that a written pseudo-skill is trackable |
| Graph rebuild becomes slow on every call | Cache keys on the corpus fingerprint; measured at 41ms for 658 nodes |
| Duplicating research into the corpus bloats retrieval | Research ranks below wiki/contract by kind weight |

## 4. Clarifications

### 4.1 Where learned pseudo-skills live

- **Question:** The operator asked for learned skills to be based in the wiki. Where exactly, given the generator owns seven filenames?
- **Options:** 1. `.agents/wiki/skills/` (a subdirectory the generator never touches); 2. mixed into the generated pages; 3. `.agents/skills/`.
- **Selected:** 1.
- **Trade-off accepted:** Current wiki readers glob non-recursively, so the subdirectory needs an explicit reader added — which is the work, not an obstacle.
- **asked:** operator
- **resolved by:** `generate_wiki`'s fixed seven filenames and its non-recursive glob.

### 4.2 How much of `.agents` to index

- **Question:** Index all 115 coordination files, or keep a recency cap?
- **Options:** 1. All, with kind weighting to keep ranking sane; 2. keep the newest-N cap.
- **Selected:** 1.
- **Trade-off accepted:** ~658 nodes and a 41ms rebuild; the cache makes this per-change, not per-query.
- **asked:** operator
- **resolved by:** the direction to "comprehensively review all of our .agents folder context files".

### 4.3 Whether research sources join the corpus

- **Question:** Should `research/` be retrievable, or is it reference material only?
- **Options:** 1. Index it; 2. leave it out.
- **Selected:** 1, weighted below wiki and contract.
- **Trade-off accepted:** 316KB of research competes for retrieval slots; weighting and section-splitting keep it from dominating.
- **asked:** operator
- **resolved by:** "allow us to continuously improve context system based on those sources I provided".

## 5. Todos

- [x] **T1** Negate the root wiki dir in `.gitignore` and assert a written pseudo-skill is trackable.
  - from: §3 | done when: `git check-ignore .agents/wiki/skills/x.md` returns nothing, nested still ignored | verify: assertion
- [x] **T2** Widen `_graph_sources`: all coordination files, `templates/`, `research/`, `wiki/skills/`.
  - from: §3 | done when: node count exceeds 600 on this repo | verify: graph census
- [x] **T3** Add `KIND_WEIGHTS` and apply them in `graph_retrieve` scoring.
  - from: §3 | done when: a wiki section outranks a comms line at equal term overlap | verify: synthetic test
- [x] **T4** Key the graph cache on the corpus definition so a widened source set invalidates it.
  - from: §3 | done when: adding a file changes the fingerprint | verify: assertion
- [x] **T5** Add pseudo-skill frontmatter validation (`title`, `tags`, `trigger`, `evidence`).
  - from: §3 | done when: a page missing `evidence` is refused | verify: validator test
- [x] **T6** Abstract at least four pseudo-skills from the four sources into `.agents/wiki/skills/`.
  - from: §3 | done when: each cites its source in `evidence` | verify: files exist and validate
- [x] **T7** Measure retrieval quality before/after on a fixed probe set; keep the change only if it holds.
  - from: §3 Risks | done when: a table of probes × top-hit exists | verify: probe script
- [x] **T8** Assertions + suite green above the 344 baseline.

## 6. Verification

- `scripts/test-pqc-dist.sh` — all previous assertions plus the new ones.
- Graph census — more than 600 nodes; `research/` and `wiki/skills/` present.
- `git check-ignore` — learned pseudo-skill trackable, nested wiki ignored.
- Probe table — a rules question, a research question, and a coordination question each hit the right kind.
- `--context` latency — within a small delta of before on a warm cache.

## 7. Open Decisions

- Whether unlimited coordination indexing should stay unlimited on a very large repo — settled by measuring a repo with thousands of comms files.
- Whether pseudo-skills should ever auto-promote — currently no; revisit only with operator sign-off.
