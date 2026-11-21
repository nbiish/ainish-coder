---
plan_format: ainish/plan/v1
slug: consolidation-panel-sequence
date: 2026-11-21
status: ready
branch: feat/consolidation-panel-sequence
worktree: /Users/nbiish/code/consolidation-panel-sequence
task_record: .agents/tasks/2026-11-21-09-consolidation-panel-sequence.md
operator: direct-instruction
---

# Plan: sequence digests so a folder can always come down, and put four agents on the review

## 1. Problem

55 records sit unconsolidated across `comms`, `memories`, `suggestions`, `tasks`, and `plans` — every
folder still over its 5-original cap — and the consolidation pass the context call spawns consolidates
**zero** of them. The cause is not effort: it is that a digest is keyed on a PERIOD, and once
`DIGEST-comms-2026-11.md` exists that period can never accept another record. Every folder with a
digest in the current period is permanently blocked, which is every folder.

`tasks` makes the absurdity visible: its digest covers **1 record** while 15 originals sit beside it.

The operator also wants the review to be a four-agent panel rather than a drafter and a checker:
consolidation, then a prime assembled from the input, the recent unconsolidated records, and the wiki.

## 2. Anchor Facts

- Unconsolidated originals: comms 8, memories 8, suggestions 5, tasks 15, plans 19 = **55**.
- Digests present: memories 3 (2026-09, 2026-10, 2026-11), tasks 1, suggestions 1, plans 1, comms 0.
- `DIGEST-tasks-2026-11.md` has `records_consolidated: 1`; 15 task records remain beside it.
- `_digest_path` builds `DIGEST-<folder>-<period>.md`; `run_context_consolidate` skips a period when
  that file exists — "digest already exists" appeared for four of five folders.
- Four hermes profiles exist and are described: `consolidate-elephant`, `consolidate-goldfish`,
  `consolidate-structural`, `consolidate-archivist`. All on `mimo-v2.6-pro`, gateway running.
- `consolidation_call(profile, prompt, fallback_role=...)` is the transport, with `pi` fallback.
- The gate (`_parse_digest_verdict`) requires `VERDICT: pass|fail` and fails closed on anything else.
- Prime sections are orientation/retrieval/elephant/goldfish; the operator chose to leave that structure.
- `main` moved to `22ef539` (a tldraw canvas feature) but touched nothing under `src/context/`.

## 3. Plan

### Goals

- A folder can ALWAYS be brought to the cap: digests form a sequence, not a period lock.
- The review is a four-agent panel with distinct jobs, each able to block.
- The prime is unchanged in shape, but fed by a record that is actually consolidated.
- The 55 backlog clears on a real run, verified folder by folder.

### Non-goals

- Changing the prime's four sections.
- Making the panel synchronous in the prime path.
- Re-summarising an existing digest into a new one (a summary of a summary loses twice).

### Constraints and invariants

- The three newest records per folder are never touched.
- `llms.txt` and `*.live.*` are never consolidated or counted.
- Nothing is written or removed unless every panel member that can block has passed.
- A digest is written before its sources are removed, and names exactly the sources it covers.
- `AGENTS.md` stays at 160 lines.

### Proposed architecture

```
context-consolidate --folder F
  ├─ census: 3 newest protected, indexes/sidecars excluded
  ├─ next digest INDEX = highest existing + 1   →  DIGEST-<folder>-NN.md
  ├─ batch records (10 per batch, measured-safe for hermes)
  │    ├─ consolidate-elephant   drafts the digest
  │    ├─ consolidate-goldfish   fidelity: does the draft follow from the sources?
  │    ├─ consolidate-archivist  completeness: anything in the sources unrepresented?
  │    └─ consolidate-structural coherence: does the digest hold together as one record?
  ├─ ALL THREE reviewers must pass, else one retry carrying their combined gaps, then abandon
  └─ write digest → read back → remove exactly the covered sources
```

### Interfaces and data

- `_digest_path(repo_root, folder, index)` — `DIGEST-<folder>-<NN>.md`, zero-padded, monotonically
  increasing; no period in the name, because the period is what blocked reuse.
- `CONSOLIDATE_PANEL = (("goldfish", "fidelity"), ("archivist", "completeness"), ("structural", "coherence"))`
  — each a profile and the question it alone answers.
- `_panel_review(folder, period, sources, draft) -> (passed, combined_gaps, per_member)`.
- `provenance.harness.consolidate` reports `folder`, `digest`, and `panel` per member.

### Files and symbols

- `src/context/engine.py` — `_digest_path`, `_next_digest_index`, `CONSOLIDATE_PANEL`,
  `_panel_review`, `_digest_in_chunks` (panel gate), `run_context_consolidate` (sequence naming,
  no period-lock skip), `spawn_consolidate` (may run more than one folder when several are over cap).
- `scripts/consolidation-skills/` — the four role skills, installed by `--rules`.
- `src/deploy_rules_sync.sh` — create all four profiles, set descriptions, install skills.
- `scripts/test-pqc-dist.sh` — assertions for sequence naming, panel veto, backlog clearance.
- `.agents/jobs/consolidate-record.md` — update the panel description.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Rewrite the period digest to absorb new records | Re-summarising a summary loses detail twice; the operator chose sequences |
| Delete stale digests and re-run | Throws away the summary that already exists; a 1-record digest is still a record of that record |
| Two reviewers, as now | The operator asked for four, and the two extra questions (completeness, coherence) are genuinely different from fidelity |
| Four parallel drafts merged | One role fan-out; the operator chose four DISTINCT roles |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Four model calls per batch is slow | Batches are 10 records; a folder of 19 is 2 batches = 8 calls, measured at ~66s each for hermes |
| A panel member blocks everything | Each returns a named gap; the retry carries all gaps at once, and a second failure abandons the period with sources intact |
| Sequence numbers collide with existing period names | The next index is computed from files matching `DIGEST-<folder>-<digits>.md`; existing period digests are left as historical |
| Old period digests keep blocking | The period-lock check is removed entirely; only the index is consulted |

## 4. Clarifications

### 4.1 How digests are keyed

- **Question:** period-keyed digests are terminal. What replaces the key?
- **Options:** 1. (chosen) a rolling sequence per folder; 2. rewrite the period digest; 3. retire stale digests.
- **Selected:** 1.
- **Trade-off accepted:** a folder accumulates one digest file per consolidation run; they are small and
  the originals are gone, so the ratio is favourable.

### 4.2 The four agents

- **Question:** how are four formed from two profiles?
- **Options:** 1. (chosen) four distinct roles; 2. the two consolidation profiles plus the prime pair; 3. four parallel copies.
- **Selected:** 1 — drafter plus three reviewers with orthogonal questions.
- **Trade-off accepted:** three reviewers per batch is 3x the cost of one; the questions are genuinely
  different (fidelity, completeness, coherence) and each has caught something real in testing.

### 4.3 The prime's shape

- **Question:** does the prime's section structure change?
- **Options:** 1. (chosen) unchanged; 2. add a panel-verdict section; 3. force the wiki into every prime.
- **Selected:** 1.
- **Trade-off accepted:** the panel's verdict is visible in provenance, not in the prime body.

## 5. Todos

- [ ] **T1** Replace period keying with a sequence index; remove the "digest already exists" lock.
  - from: §4.1 | done when: a folder with an existing digest can still consolidate | verify: dry run
- [ ] **T2** Add `CONSOLIDATE_PANEL` and `_panel_review` with the three orthogonal questions.
  - from: §4.2 | done when: any member's fail blocks the write | verify: a constructed fixture
- [ ] **T3** Wire the panel into `_digest_in_chunks`, combining gaps for the retry.
  - from: §4.2 | done when: a draft failing two panel members retries with both gaps named | verify: suite
- [ ] **T4** Provision all four profiles and their skills from `--rules`.
  - from: §4.2 | done when: `hermes profile list` shows four, described | verify: that command
- [ ] **T5** Run consolidation on all five folders and prove each reaches ≤5 originals.
  - from: §3 | done when: every folder reports ≤5 or a named panel refusal | verify: the census
- [ ] **T6** Update the job record, AGENTS.md if needed, and the suite.
  - from: §3 | done when: 160 lines and suite above 440 | verify: both

## 6. Verification

- `scripts/test-pqc-dist.sh` — passes above 440 assertions.
- `wc -l < AGENTS.md` — 160.
- `hermes profile list` — four `consolidate-*` profiles, each described.
- After a real run: `find .agents/<folder> -maxdepth 1 -name '2026-*' | wc -l` ≤ 5 for all five.
- A digest written by the panel names its sources and every one is recoverable with `git show`.

## 7. Open Decisions

- Whether every batch needs all three reviewers or the archivist and structural can run only when the
  batch is large — settled by whether the small batches produce real findings.
- Whether digests should ever be re-consolidated into a coarser one — settled by how many accumulate in
  a year.
