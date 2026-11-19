---
plan_format: ainish/plan/v1
slug: context-agent-correctness
date: 2026-11-19
status: done
branch: feat/context-agent-correctness
worktree: /Users/nbiish/code/context-agent-correctness
task_record: .agents/tasks/2026-11-19-14-context-agent-correctness.md
operator: direct-instruction
---

# Plan: make `ainish-coder --context` a real self-improving context agent

## 1. Problem

The context system is the product: one command an agent calls after reading `AGENTS.md`, returning
repo context and improving itself from the repo's own history. Measured on `fbc3186`, it does not do
that. The corpus is 60 of 167 files because the shipped profile still caps artifacts at 2 and wiki
pages at 8 while the engine constant says unlimited. The learning loop cannot accept: its only
external referent is commit-subject word overlap, which 5 of 10 real task objectives cannot satisfy,
and this repo has never produced a generation. The command is still named `ainish-rag`, the wiki
cannot be refreshed on a real vault, `weights` is a validated no-op, two disjoint skill surfaces
exist, and the contract claims a reviewer refusal the code does not implement.

## 2. Anchor Facts

- `GRAPH_MAX_ARTIFACTS = 0` / `GRAPH_MAX_WIKI_PAGES = 0` where 0 means unlimited —
  `src/rag/rag.py:3601-3602`, comment at `:3597`.
- `BASE_PROFILE` ships `max_artifacts: 2, max_wiki_pages: 8` — `src/rag/context_harness.py:99-118`.
- `run_context_command` always folds a profile over `base_settings()` — `src/rag/rag.py:6005-6007`.
- Measured corpus: plans 24 on disk / 2 in graph; comms 17/2; memories 19/2; suggestions 14/2;
  tasks 42/2 — `_graph_sources(root, settings)` census.
- `outcome_signal` needs ≥2 of the 6 longest task words in a commit subject —
  `src/rag/context_harness.py:551-566`; 5/10 real task objectives reachable.
- `spawn_autolearn` passes the raw task string, whose commit cannot exist at call time —
  `src/rag/rag.py:5926`.
- `.agents/context-harness/` contains only `.gitignore` in git; no profile, history, or
  `EXPERIENCE.md` has ever been written here — `git ls-files`, `context-status`.
- `--refresh-wiki` refuses on this repo: vault pages carry `ainish/wiki` — `VAULT_TAG`,
  `src/rag/rag.py:1161`, `generate_wiki:1194`.
- `weights` is folded by `apply_to_settings` and bounded by `validate_profile`, but
  `graph_retrieve:4002` reads `GRAPH_KIND_WEIGHTS` and never `settings["weights"]` — grep.
- `recency_floor: 0.0` resolves to 0.55 and `hop_bonus: 0.0` to 0.35 because of `or` —
  `src/rag/rag.py:3982-3984`, replayed.
- `plan_reviewer_model` (`src/rag/rag.py:2771`) has no callers; `:6150` hardcodes `distinct-model`.
- Edge census: 307 nodes, 17,790 edges, 57.9/node; research contributes 10,519 out-edges,
  `AGENTS.md#46` alone 221.
- `AGENTS.md` is a hard 160 lines (`scripts/test-pqc-dist.sh:722`, `:878`).
- `.agents/wiki/skills/` (6 pages) and `.agents/context-harness/skills/` (absent) are disjoint: the
  graph indexes the first as `pseudoskill`, `render_staged_skills` reads the second.

## 3. Plan

### Goals

- `ainish-coder --context "<input>"` is the user-facing entry point; `ainish-rag` forwards with one
  deprecation line and keeps working.
- The graph indexes the whole declared corpus, verified by a census assertion.
- Every tuning value the profile accepts is a value the engine honours.
- One learn cycle can reach `accepted` on a repo with a completed task record, and rollback restores
  the prior fingerprint.
- The context agent can refresh and edit the wiki through the native renderer.
- One self-editing skill surface, indexed and rendered from the same directory.
- Reviewer isolation is a fact reported truthfully, and the contract states what the code does.

### Non-goals

- Renaming `src/rag/rag.py`, the Rust crate, or the `rag` subcommand namespace: 9k lines of import
  churn for no behavioural gain. The user-facing surface is what changes.
- Rewriting `.agents/{plans,tasks,comms,research}` historical records: renaming a record falsifies it.
- Cross-repo library transfer and `k>1` candidate recursion: cost without a proven single-repo loop.

### Constraints and invariants

- `AGENTS.md` stays at 160 lines; every non-negotiable preserved.
- `src/rag/rag.py` stays stdlib-only.
- The budget ladder in `assemble_injection` is untouched; no new injection section.
- Nothing learned is auto-discovered by other harnesses until an operator promotes it.
- A missing or invalid profile must never raise into `--context`.
- Historical `.agents/` records are immutable.

### Proposed architecture

```
ainish-coder --context "<input>"
  └─ exec ainish-rag context --task "<input>"      (one deprecation-free hop)

ainish-rag context
  ├─ orientation   branch, tree, COMMS, task, plan, rules digest, gate verdict
  ├─ retrieval     graph over contract + wiki + .agents/* + research + learned skills
  ├─ elephant / goldfish                          (reviewer ladder, truthful provenance)
  └─ spawn detached learner (6h AND >=1 new commit)

context-learn
  ├─ referent: task record status:done + merge commit after branch point
  │            | --outcome ok|fail|unknown
  │            | commit-subject overlap (last resort)
  ├─ KEEP_BASE / accepted / refused / error       (four distinct outcomes)
  └─ accepted -> profile + staged skill + EXPERIENCE.md + wiki page
```

### Interfaces and data

- `ainish-coder --context "<input>" [--json] [--retrieval-only] ...` — new; task is the first
  non-flag argument, remaining flags pass through.
- `context_harness.BASE_PROFILE["graph"]` — `max_artifacts` and `max_wiki_pages` become `0` ("all").
- `context_harness.BOUNDS` — both caps widen to `(0, 64)`.
- `outcome_signal(repo_root, task, *, max_commits=60, task_record=None, override=None)` — new
  keyword arguments; returns `referent` naming which source decided it.
- `ainish-rag context-learn [--task T] [--task-record PATH] [--outcome ok|fail|unknown] [--dry-run]`.
- `ainish-rag context-wiki-edit <name> --title T --evidence PATH [--body TEXT]` — new bounded write.
- `provenance.drivers.reviewer_isolation` — `distinct-model` | `fresh-context` | `refused`.
- `GRAPH_EXTRA_SOURCES` — `pseudoskill` points at `.agents/context-harness/skills`.

### Files and symbols

- `bin/ainish-coder` — `--context` case in `main`'s dispatcher.
- `bin/ainish-rag` — deprecation notice (suppressed when forwarded), corrected header.
- `AGENTS.md` — command name at `:13`, `:21`; reviewer sentence; line-neutral.
- `src/rag/context_harness.py` — `BASE_PROFILE`, `BOUNDS`, `base_settings`, `outcome_signal`,
  `_slug_words`, `validate_tree`, `write_wiki_page`, `refresh_vault`.
- `src/rag/rag.py` — `graph_retrieve` (falsy-zero and weights), `build_wiki_graph` (edge bound),
  `run_context_command` (reviewer ladder, vault refresh), `run_context_learn` (`--task-record`,
  `--outcome`), `spawn_autolearn`, `run_context_wiki_edit`, argparse, `--help`.
- `scripts/test-pqc-dist.sh` — repoint the pinned cap assertion; end-to-end block.
- `llms.txt` — retired-vector wording, wiki filenames matching disk.
- `.agents/wiki/02,05,06` — purge present-tense embedding text.
- `research/context-priming-master/probe_corpus.py` — plan/task/comms probes.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Keep `ainish-rag` as the documented command | The operator asked for prompting vocabulary; agents follow the one sentence in `AGENTS.md` |
| Fix the caps by editing the engine constants back to 2 | That reverts the 2026-11-18 finding that 105 of 115 files were invisible |
| Gate on a model's judgement of prime quality | Phase 0 proved prime-derived signals circular (rho up to 1.000) |
| Delete `weights` rather than wire it | Provenance would keep reporting a knob; a reported knob must act |
| Auto-promote learned skills to `.agents/skills/` | That directory is standing prompt surface for every harness |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Wider corpus dilutes ranking | Edge bound plus the probe table; accept only if plan/task/comms probes improve |
| Cap change alters every repo's prime | Generation 0 is reseeded deliberately; rollback proven first |
| Migrating pseudo-skills loses lessons | All six moved before the old directory is removed; `context-status` shows one list |
| Vault refresh writes tracked files | Only on explicit `--refresh-wiki`; the native renderer owns the format |
| Loop still cannot accept on prose tasks | `--outcome` override; `KEEP_BASE` is a legal outcome, `error` is not |

## 4. Clarifications

### 4.1 The command name

- **Question:** The operator said the RAG vocabulary is retired and the command should be `ainish-coder --context {input}`. Does `ainish-rag` survive?
- **Options:** 1. (Recommended) Add `ainish-coder --context` and keep `ainish-rag` as a forwarding launcher with one deprecation line; 2. Rename outright and break older `AGENTS.md` copies; 3. Add an alias and document both equally.
- **Selected:** 1.
- **Trade-off accepted:** Two names exist; only one is advertised.
- **asked:** operator
- **resolved by:** n/a

### 4.2 Which self-editing skill surface

- **Question:** Staged skills live at `.agents/context-harness/skills/` and the graph indexes `.agents/wiki/skills/`. Which is the system's own?
- **Options:** 1. (Recommended) `.agents/context-harness/skills/`, indexed into the graph, `.agents/wiki/skills/` retired; 2. Keep both and index both; 3. Keep only the wiki copy.
- **Selected:** 1.
- **Trade-off accepted:** Overrules the 2026-11-18 choice; the six existing pages must be migrated, not abandoned.
- **asked:** resolved from code
- **resolved by:** `render_staged_skills` globs `*/SKILL.md`; the graph globs `.agents/wiki/skills`. Two surfaces, zero overlap.

### 4.3 The acceptance referent

- **Question:** The gate needs an external referent. Which one is primary?
- **Options:** 1. (Recommended) A task record at `status: done` plus a merge commit after its branch point, with `--outcome ok|fail|unknown` as the explicit override; 2. `--outcome` only; 3. keep commit-subject overlap.
- **Selected:** 1, with `unknown` reported distinctly from `false`.
- **Trade-off accepted:** Depends on the repo keeping task records; an `error` is a distinct outcome, never a silent `KEEP_BASE`.
- **asked:** resolved from code
- **resolved by:** measured 5/10 reachability of the overlap signal; `rejected/20261119T141442Z.md`.

### 4.4 Reviewer isolation

- **Question:** `AGENTS.md` says the review is refused without a distinct model; the code accepts a fresh same-model context. Which becomes true?
- **Options:** 1. (Recommended) Report the ladder honestly: distinct model, fresh-context (verdict marked provisional), or refused on a pinned collision; wire the unused `plan_reviewer_model` so the refusal is real; 2. Force refusal on every same-model host; 3. Keep the current unconditional `distinct-model` claim.
- **Selected:** 1.
- **Trade-off accepted:** A same-model review keeps running, but is labelled provisional rather than independent.
- **asked:** operator
- **resolved by:** n/a

## 5. Todos

- [x] **T1** Add `--context` to `bin/ainish-coder`, deprecation notice to `bin/ainish-rag`, and update the two `AGENTS.md` references.
  - from: §4.1 | done when: `ainish-coder --context "probe"` returns a prime and `wc -l AGENTS.md` is 160 | verify: `./bin/ainish-coder --context "probe" --retrieval-only | head -3; wc -l < AGENTS.md`
- [x] **T2** Align `BASE_PROFILE` and `BOUNDS` with the engine, fix the falsy-zero `or`, and wire `weights` into `graph_retrieve`.
  - from: §3 | done when: a 0-cap profile indexes every coordination file and `recency_floor: 0.0` resolves to 0.0 | verify: census + replay
- [x] **T3** Give `outcome_signal` a task-record referent and `run_context_learn` the `--task-record` / `--outcome` flags; seed generation 0 here.
  - from: §4.3 | done when: a learn cycle on a completed task record reaches `accepted` or `KEEP_BASE`, never `error` | verify: `context-learn --dry-run --task-record ...`
- [x] **T4** Dispatch `--refresh-wiki` to the native renderer and add `context-wiki-edit`.
  - from: §3 | done when: `--refresh-wiki` reports `refreshed`, not `refused` | verify: `./bin/ainish-rag context --task probe --retrieval-only --refresh-wiki`
- [x] **T5** Point `GRAPH_EXTRA_SOURCES` at the harness skills directory, migrate the six pages, retire `.agents/wiki/skills/`.
  - from: §4.2 | done when: `context-status` lists the six under one heading and the graph has `pseudoskill` nodes there | verify: `context-status` + graph census
- [x] **T6** Wire `plan_reviewer_model` and implement the three-way reviewer ladder; correct the `AGENTS.md` sentence.
  - from: §4.4 | done when: provenance reports one of three states and a pinned collision refuses | verify: `--json` provenance
- [x] **T7** Purge present-tense embedding text from `llms.txt`, the launcher header, and wiki 02/05/06; fix wiki filenames.
  - from: §3 | done when: no present-tense `llama-server`/LanceDB claim survives in corpus | verify: grep
- [x] **T8** Extend `probe_corpus.py` with plan/task/comms probes and bound out-edges per node.
  - from: §3 | done when: the probe table improves on coordination probes and no contract probe regresses | verify: `python3 research/context-priming-master/probe_corpus.py`
- [x] **T9** Add the end-to-end deployment assertions to `scripts/test-pqc-dist.sh`.
  - from: §6 | done when: seed → context → accepted → rollback is one passing block | verify: `scripts/test-pqc-dist.sh`

## 6. Verification

- `scripts/test-pqc-dist.sh` — passes above the 354 baseline.
- `wc -l < AGENTS.md` — exactly 160, every non-negotiable greps present.
- `./bin/ainish-coder --context "..."` — returns a prime naming the new command.
- `ainish-rag context-status` — `history: 1 generation(s)` and one skill list.
- `--refresh-wiki` — `refreshed (N pages)`.
- `context-rollback 0` — restores fingerprint `cf19d36708eaa433`.

## 7. Open Decisions

- Whether the edge bound should be a profile knob rather than a constant — settled after the probe
  table shows whether one bound serves every corpus size.
- Whether `context-wiki-edit` should be reachable from `--context` itself — settled after the learner
  authors a page an operator judges worth keeping.
