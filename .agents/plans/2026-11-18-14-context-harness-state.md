---
plan_format: ainish/plan/v1
slug: context-harness-state
date: 2026-11-18
status: implementing
branch: fix/context-harness-state
worktree: /Users/nbiish/code/context-harness-state
task_record: .agents/tasks/2026-11-18-14-context-harness-state.md
operator: direct-instruction
---

# Plan: bound the context-harness state directory

## 1. Problem

The context harness is designed to run for the life of a repository, and two of its directories grow
without limit: every learning pass writes an evidence tree under `work/` and never removes one, and every
refusal appends a file to `rejected/` forever. Unbounded growth is the failure this project's own research
names as dominant (the practitioner video's harness consumed 100% of its savings on self-bloat), so a
learning loop that slowly fills a repository is the same defect at a larger timescale.

## 2. Anchor Facts

- `work/<stamp>/` is written by `_harness_evidence_tree` once per pass; nothing removed prior trees.
- `rejected/<stamp>.md` is appended by `record_rejection` on every refusal; nothing capped it.
- `.agents/context-harness/` is **not** gitignored (`git check-ignore` returns nothing), so everything
  written there is a candidate for commit.
- `work/` and `.learn.lock` are per-machine operational traces, not learned state; the profile,
  `EXPERIENCE.md`, `history/`, `skills/` and `rejected/` are learned state that must survive a clone.

## 3. Plan

### Goals

- Cap `work/` at the newest ten trees and `rejected/` at the newest fifty files.
- Prune at the **start** of a pass, so the evidence that pass just produced can never be what is removed.
- Commit learned state; gitignore operational traces.

### Non-goals

- A retention policy based on age rather than count — count is simpler and bounds the repository.
- Compressing old evidence trees; they are small and the newest ten are enough.

### Constraints and invariants

- Pruning must never be able to run before the directory exists, or before a pass has written anything.
- A `.gitignore` inside `.agents/context-harness/` must not hide learned state.

### Interfaces and data

- `prune_work(root, *, keep=10, keep_rejected=50) -> int` — replaced the earlier `keep`-only signature.

### Files and symbols

- `src/rag/context_harness.py` — `prune_work` gains the `rejected/` cap.
- `src/rag/rag.py` — the call moves to the start of `_learn_locked`.
- `.agents/context-harness/.gitignore` — new; enumerates what is and is not committed.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Pruning removes the current pass's evidence | It runs before the pass writes |
| A `.gitignore` here hides learned state | It names only `work/`, `.learn.lock`, `.skills-backup/` |

## 4. Clarifications

### 4.1 Where the prune call belongs

- **Question:** Should pruning run before or after a pass writes its evidence?
- **Options:** 1. After, so the newest tree is counted; 2. (Chosen) Before, so the newest tree can never be the one removed.
- **Selected:** 2.
- **Trade-off accepted:** The directory briefly holds `keep+1` trees during a pass.
- **asked:** resolved from code
- **resolved by:** the ordering defect in the first attempt, where the call sat after `_harness_evidence_tree`.

## 5. Todos

- [x] **T1** Cap `rejected/` alongside `work/` in `prune_work`.
  - from: §3 | done when: 60 refusals reduce to 50 | verify: pruning test
- [x] **T2** Move the prune call to the start of `_learn_locked`.
  - from: §4.1 | done when: it precedes `_harness_evidence_tree` | verify: read of the function
- [x] **T3** Add `.agents/context-harness/.gitignore` distinguishing learned state from traces.
  - from: §3 | done when: `work/` is ignored and `prime-profile.json` is not | verify: `git check-ignore`
- [x] **T4** Add assertions for both caps and the ignore file.
  - from: §3 | done when: suite exceeds the 342 baseline | verify: `scripts/test-pqc-dist.sh`

## 6. Verification

- `scripts/test-pqc-dist.sh` — 343 assertions pass.
- `prune_work` on 14 work dirs + 60 rejections leaves 10 and 50.
- `git check-ignore .agents/context-harness/work/x` matches; `prime-profile.json` does not.

## 7. Open Decisions

- Whether fifty refusals is the right cap — settled if the audit trail proves too short in practice.
