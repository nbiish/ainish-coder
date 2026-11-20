---
plan_format: ainish/plan/v1
slug: context-consolidation
date: 2026-11-20
status: done
branch: feat/context-consolidation
worktree: /Users/nbiish/code/context-consolidation
task_record: .agents/tasks/2026-11-20-14-context-consolidation.md
operator: direct-instruction
---

# Plan: consolidate the context folders into dated digests, and cap them

## 1. Problem

`.agents/{memories,comms,tasks,suggestions,plans}` hold **136 files, ~195K tokens** — every one of them
indexed by the retrieval graph, so the corpus grows without bound and an agent reading the record spends
its budget on raw history. The operator wants the context agents (elephant and goldfish) to consolidate
that history into dated digests that keep what was accomplished, what was left unfinished, the insights,
and what keeps repeating — while leaving the three newest versions untouched so recent work is readable
normally. No folder should hold more than 5 originals, so the record stays reviewable and still teaches
the system something.

## 2. Anchor Facts

- File counts: memories 21, comms 19, tasks 47, suggestions 19, plans 30 = **136**.
- Tokens: memories ~27.8K, comms ~42.5K, tasks ~50.2K, suggestions ~11.9K, plans ~62.9K.
- The graph indexes **every** file in those folders (`GRAPH_MAX_ARTIFACTS = 0` = all), so capping
  removes 111 of 433 nodes from retrieval unless digests carry that knowledge forward.
- `memories/llms.txt` and `plans/llms.txt` are DIRECTORY INDEXES, not dated records — counting or
  consolidating them would destroy the map of the folder.
- Five comms files are `.live.txt` operational sidecars and **gitignored**: `2026-11-10-team.live.txt`,
  and four `*-identity-guard.live.txt`. Deleting those is unrecoverable.
- All 136 dated records are otherwise tracked, so `git show <sha>:<path>` can restore any of them.
- Records are dated in their FILENAME (`YYYY-MM-DD-...`), so grouping by period is mechanical.
- Task records carry `- status:`, `- objective:`, `- scope:`, `- branch:`; memories carry
  `HH:MM UTC -- title` headings; comms are one ledger per UTC date with `- input:` / `- output:` /
  `- verification:` / `- findings:` lines.
- `context-learn` already makes model calls and has a lock, a throttle, and a `--dry-run` contract.

## 3. Plan

### Goals

- A `context-consolidate` verb that turns old records into a dated digest per folder per period, keeps
  the 3 newest originals untouched, and enforces a 5-original cap.
- Digests capture: accomplished, unfinished, insights, recurring themes, and the file list consolidated.
- Digests cite their sources, so any claim can be checked against `git show`.
- The graph indexes digests, so consolidation does not lose the knowledge.

### Non-goals

- Deleting anything git cannot restore. `.live.txt` sidecars and `llms.txt` indexes are excluded.
- Consolidating `research/`, `wiki/`, or `templates/`: different kinds with different lifecycles.
- Changing what the retrieval graph considers corpus beyond counting digests as records.

### Constraints and invariants

- The 3 newest records per folder are never read by the consolidator and never modified.
- `llms.txt` and `*.live.txt` are never counted toward the cap and never consolidated.
- A digest is written BEFORE its sources are removed; a failed write leaves the originals in place.
- Runs under the same exclusive lock as `context-learn`, so two consolidations cannot interleave.
- Nothing is removed without the file list being recorded inside the digest that replaces it.

### Proposed architecture

```
ainish-context context-consolidate [--folder F] [--dry-run] [--period month|week] [--cap 5] [--json]
  ├─ lock (shared with context-learn)
  ├─ for each folder in memories, comms, tasks, suggestions, plans
  │    ├─ skip llms.txt and *.live.txt
  │    ├─ sort by record date (filename), newest 3 = PROTECTED
  │    ├─ candidates = protected-excluded; group by period
  │    └─ for each period with >= 2 records AND not already digested
  │         ├─ elephant reads the records, drafts the digest  (accomplished / unfinished / insights / recurring)
  │         ├─ goldfish reviews the digest against the sources and names anything unsupported
  │         ├─ write DIGEST-<folder>-<period>.md
  │         └─ only then `git rm` the sources it consolidated
  └─ report: digests written, files consolidated, folder now at N originals
```

### Interfaces and data

- `run_context_consolidate(repo_root, *, folder=None, dry_run=False, period="month", cap=5, json_out=False)`.
- Digest filename: `DIGEST-<folder>-<period>.md`, e.g. `DIGEST-tasks-2026-11.md`.
- Digest frontmatter: `format`, `folder`, `period`, `records_consolidated`, `consolidated_at`,
  `sources` (one path per line), `cap_after`.
- Digest body sections: `## Accomplished`, `## Unfinished`, `## Insights`, `## Recurring`,
  `## Sources` (explicit list, so a reader can verify).
- `folder_census(repo_root, folder) -> {originals, digests, protected, consolidatable}`.
- Exclusion predicate: `_is_consolidatable(path)` — false for `llms.txt` and `*.live.txt`.

### Files and symbols

- `src/context/engine.py` — `run_context_consolidate`, `_is_consolidatable`, `_record_period`,
  `_digest_prompt`, `_write_digest`, argparse verb, help paragraph.
- `src/context/context_harness.py` — `consolidation_state_path` (throttle, mirroring autolearn).
- `AGENTS.md` — one line in *Close*: old records are consolidated, not accumulated.
- `scripts/test-pqc-dist.sh` — assertions for the exclusion rules, the protection rule, the ordering
  (digest before delete), the cap, and a dry run writing nothing.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Deterministic extraction only | Operator chose model-written digests; a script can list status fields but cannot say what an insight was |
| Archive instead of merge | Operator chose merge in place; git is the archive, and the digest names every source path |
| One digest for all folders | A single file hides which folder a lesson came from; per-folder digests keep the map |
| Never delete, just cap reading | Files would still accumulate and the folder stays unreviewable at a glance |
| Consolidate `*.live.txt` too | Untracked and gitignored — deletion would be unrecoverable, and they are operational logs, not records |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| A digest omits something the sources held | Digest lists every source path; sources stay in git; goldfish is asked to name anything unsupported |
| Deleting untracked sidecars | Hard exclusion in code, plus a test asserting they are never candidates |
| Two runs clobber each other | Shared exclusive lock; period already digested is skipped |
| The cap deletes recent work | The 3 newest are computed by record date and never even read |
| Corpus knowledge drops when 111 files leave | Digests are indexed as their folder's kind and carry the summary forward |

## 4. Clarifications

### 4.1 How the digest is produced

- **Question:** Deterministic extraction, model-written, or a hybrid?
- **Options:** 1. Deterministic; 2. (chosen) model-written by elephant and goldfish; 3. hybrid.
- **Selected:** 2 — model-written.
- **Trade-off accepted:** Costs a session per folder-period and can omit detail; mitigated by citing sources and keeping them in git.

### 4.2 What happens to the originals

- **Question:** Archive, merge in place, or preview only?
- **Options:** 1. Archive to `.agents/archive/`; 2. (chosen) merge in place; 3. preview only.
- **Selected:** 2 — merge in place.
- **Trade-off accepted:** Recovery depends on git. Untracked and index files are therefore excluded in code.

### 4.3 The cap

- **Question:** Does the 5 include digests?
- **Options:** 1. 5 total; 2. (chosen) 5 originals with digests counted separately.
- **Selected:** 2 — 5 originals, digests separate.
- **Trade-off accepted:** A folder can show more than 5 files once digests exist; the reviewable set is the originals.

## 5. Todos

- [x] **T1** Add `_is_consolidatable` and `_record_period`, excluding `llms.txt` and `*.live.txt`.
  - from: §3 | done when: census reports 5 comms candidates fewer than file count | verify: census output
- [x] **T2** Add `folder_census` and the 3-newest protection computed by record date.
  - from: §3 | done when: the 3 newest are never listed as candidates | verify: census on a fixture
- [x] **T3** Add the elephant digest prompt and the goldfish review of it.
  - from: §4.1 | done when: a digest names accomplished/unfinished/insights/recurring and every source | verify: a real dry run
- [x] **T4** Write the digest, then remove only its sources, under the shared lock.
  - from: §3 | done when: a failed digest write leaves every original in place | verify: simulated write failure
- [x] **T5** Wire `context-consolidate` into argparse and help; add the `Close` line to AGENTS.md.
  - from: §3 | done when: the verb appears in `--help` and AGENTS.md is 160 lines | verify: both
- [x] **T6** Add suite assertions for exclusion, protection, ordering, cap, and dry-run.
  - from: §3 | done when: suite passes at or above 418 | verify: `scripts/test-pqc-dist.sh`

## 6. Verification

- `scripts/test-pqc-dist.sh` — passes at or above 418 assertions.
- `wc -l < AGENTS.md` — 160.
- `ainish-context context-consolidate --dry-run` — lists what it would consolidate and changes nothing (`git status` clean).
- After a real run on one folder, that folder holds 3 originals + 1 digest, and `git show HEAD~1:<path>` still yields every consolidated record.
- `llms.txt` and `*.live.txt` still present and untouched.

## 7. Open Decisions

- Whether digests should be regenerated when a period gains a new record, or only once — settled by
  whether a monthly digest ever needs a late addition.
- Whether the cap should be per-folder configurable via the harness profile — settled after the first
  run shows whether one number suits all five folders.
