---
plan_format: ainish/plan/v1
slug: comms-block-parsing
date: 2026-11-18
status: done
branch: fix/comms-block-parsing
worktree: /Users/nbiish/code/comms-block-parsing
task_record: .agents/tasks/2026-11-18-15-comms-block-parsing.md
operator: direct-instruction
---

# Plan: orientation reads both COMMS entry delimiters

## 1. Problem

The orientation section reports "today's COMMS, last entry" so a fresh agent learns what just happened.
On the current ledger format it reported `last entry: ---` — the frontmatter fence — because the parser
only split on `### ` headings. An agent reading that learns nothing, which is worse than omitting the
line, because it looks like state was gathered.

## 2. Anchor Facts

- The parser splits on `"\n### "` only (`src/rag/rag.py:render_orientation_section`).
- Current COMMS entries are delimited by `---` frontmatter blocks, not `### ` headings.
- Observed on this repository: a real context call printed `- today's COMMS, last entry: ---`.
- Two delimiter styles are live in `.agents/comms/`, so both must be accepted.

## 3. Plan

### Goals

- Split on either `### ` or a `---` fence.
- Skip a header that is a bare fence, and prefer status/objective when present.
- A regression assertion that a `---`-delimited ledger reports its status and objective.

### Non-goals

- Rewriting historical COMMS files into one format.
- Parsing any richer structure than `- key: value` lines.

### Constraints and invariants

- Orientation must never raise on a malformed ledger; it already wraps reads in `try/except OSError`.
- The change must not alter output for `### `-style ledgers.

### Interfaces and data

- `render_orientation_section` block-splitting regex: `(?m)^(?:### |---\s*$)`.

### Files and symbols

- `src/rag/rag.py` — the COMMS block inside `render_orientation_section`.
- `scripts/test-pqc-dist.sh` — one new assertion.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Splitting on `---` also splits on horizontal rules mid-entry | A `---`-only line is a fence in this format; the last block still carries the newest entry |
| Header becomes empty | Explicitly fall back to omitting the header rather than printing a fence |

## 4. Clarifications

### 4.1 Which delimiter wins

- **Question:** Should the parser be rewritten to one format, or accept both?
- **Options:** 1. Migrate all ledgers to one style; 2. (Chosen) Accept both.
- **Selected:** 2 — historical ledgers are append-only records and must not be rewritten.
- **asked:** resolved from code
- **resolved by:** both styles present under `.agents/comms/`.

## 5. Todos

- [x] **T1** Split on both delimiters and skip a bare fence header.
  - from: §3 | done when: a `---` ledger reports status and objective | verify: assertion
- [x] **T2** Add the regression assertion.
  - from: §3 | done when: suite exceeds 343 | verify: `scripts/test-pqc-dist.sh`

## 6. Verification

- `scripts/test-pqc-dist.sh` — 344 assertions pass.
- `render_orientation_section` on a synthetic `---` ledger prints `status: done` and the objective.

## 7. Open Decisions

None.
