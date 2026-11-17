---
plan_format: ainish/plan/v1
slug: federation-discoverability
date: 2026-11-17
status: implementing
branch: feat/federation-discoverability
worktree: /Users/nbiish/code/federation-discoverability
task_record: .agents/tasks/2026-11-17-13-federation-discoverability.md
operator: question-me
---

# Plan: make federation discoverable to agents that did not build it

## 1. Problem

`--machine-sync`, `--machine-link`, and `--machine-watch` are documented in `ainish-coder --help`,
`README.md`, and `llms.txt`, but an agent that follows the mandatory workflow — call `ainish-rag
--context`, read `AGENTS.md` — never learns they exist. `ainish-rag --help` mentions federation zero
times, and `AGENTS.md` zero times. A future agent will therefore rebuild or hand-roll cross-machine
sync instead of using the tool, which is the specific failure this task exists to prevent.

## 2. Anchor Facts

- `ainish-coder --help` mentions `machine-sync|machine-link|machine-watch` 25 times — established by
  `grep -c`.
- `ainish-rag --help` mentions `machine|federat` **0 times** — same command.
- `AGENTS.md` mentions `machine-sync|machine-link|machine-watch|federat` **0 times** — same command.
- `src/rag/rag.py` has no reference to federation — `grep -rn` returns nothing.
- **`AGENTS.md` is exactly 160 lines against a hard 160-line gate** (`scripts/test-pqc-dist.sh:718`,
  `:866`). Any addition without a matching trim fails the PQC gate.
- Section sizes: `## Start here` 8, `## The context call` 23, `## Non-negotiables` 31,
  `## Security-first posture` 32, `## Destructive commands` 13, `## Worktrees` 7, `## Close` 7,
  `## Where everything else lives` 18, `## Writing` 12.
- `ainish-rag` help is composed by argparse with `RawDescriptionHelpFormatter` (`:6703`).
- The `ORIENT_PRIMER` is generated from the wiki vault, so hand-authored guidance cannot live there.
- Stale state found: `.agents/tasks/2026-11-15-09-watch-suggestions.md` still reads
  `status: implementing` although its work merged (`e08333a`) — it is the record `--context`
  orientation shows an agent today.

## 3. Plan

### Goals

- An agent reading `ainish-rag --help` learns that cross-machine sync exists and what to call.
- An agent reading `AGENTS.md` sees the pointer, within the line gate.
- `--context` orientation does not advertise a task as in-progress when it is merged.

### Non-goals

- No change to federation behaviour; this is discoverability and record hygiene only.
- No new CLI surface — the verbs already exist.
- No wiki/primer edit (generated, not hand-authored).

### Constraints and invariants

- `AGENTS.md` must remain **≤ 160 lines**; the trim must be prose redundancy, not a rule.
- The `ainish-rag` help must stay short enough to read; one pointer block, not a manual.
- Nothing here may weaken the security posture section.

### Proposed architecture

Three surfaces, cheapest first:

```
ainish-rag --help   ──► a "cross-machine" paragraph: what exists, the one command to start
AGENTS.md           ──► one table row in "Where everything else lives" (trim 1-2 lines to fit)
task record         ──► mark the merged task done, so orientation stops reporting it as active
```

### Interfaces and data

- `ainish-rag --help`: a short `CROSS-MACHINE` paragraph naming `--machine-link … --watch` as the
  one-time setup and `--machine-sync --latest` as the "which copy is newest" query.
- `AGENTS.md`: one added row, `| Working on this repo from more than one machine | ainish-coder
  --machine-sync / --machine-link (README §Cross-machine federation) |`.

### Files and symbols

- `src/rag/rag.py` — the argparse `description` at `:6703`.
- `AGENTS.md` — the pointer table, plus a compensating trim.
- `.agents/tasks/2026-11-15-09-watch-suggestions.md` — status correction with evidence.
- `scripts/test-pqc-dist.sh` — assertions that both surfaces keep naming federation (a discoverability
  claim with no gate decays back to zero).
- `llms.txt` — a line recording that the discovery surfaces are gated.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Put it in `ORIENT_PRIMER` | Generated from the wiki; hand edits are overwritten. |
| Grow `AGENTS.md` past 160 | The gate exists so the contract is read whole; raising it for a pointer is the wrong trade. |
| Only document in `README.md` | Agents do not read the README before acting; they read the contract and `--help`. |
| Add a new `--federation` verb | Three verbs already exist; a fourth adds surface without adding capability. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Trim removes a rule | Trim only prose, then diff the Non-negotiables and Security sections for zero loss |
| Help paragraph bloats | One paragraph, ≤ 8 lines, gate-checked |
| Assertions rot | Assertions check for the verb names, which are stable |

## 4. Clarifications

### 4.1 Where the agent-facing pointer belongs

- **Question:** `ainish-rag --help`, `AGENTS.md`, or both?
- **Options:** 1. (Recommended) both — `--help` is what an agent greps, `AGENTS.md` is what it reads
  before acting; 2. `--help` only; 3. `AGENTS.md` only.
- **Selected:** both, within the 160-line gate.
- **Trade-off accepted:** one pointer row must be paid for with a small trim elsewhere.
- **asked:** resolved from code
- **resolved by:** AGENTS.md at 160/160 and rag help at 0 mentions.

### 4.2 What to trim to stay at 160

- **Question:** Which lines make room?
- **Options:** 1. (Recommended) compress the `## Start here` numbered prose (8 lines) into the same
  three steps more tightly; 2. raise the gate; 3. skip `AGENTS.md`.
- **Selected:** option 1. The steps remain identical in meaning; the gate is a deliberate decision and
  not mine to raise.
- **Trade-off accepted:** slightly denser prose in the first section an agent reads.
- **asked:** resolved from code
- **resolved by:** the gate at `scripts/test-pqc-dist.sh:866`.

## 5. Todos

- [x] **T1** Add the cross-machine paragraph to the `ainish-rag --help` description.
- [x] **T2** Add the pointer row to `AGENTS.md` and trim prose so it stays ≤ 160.
- [x] **T3** Correct the stale task record to `done` with merge evidence.
- [x] **T4** Gate both surfaces in `scripts/test-pqc-dist.sh`; note it in `llms.txt`.
- [x] **T5** Verify: help renders, AGENTS.md line count, both gates green.

## 6. Verification

- `ainish-rag --help | grep -c machine` — at least 2.
- `wc -l AGENTS.md` — ≤ 160.
- `bash scripts/test-pqc-dist.sh` — passes, including the new assertions.
- `bash scripts/test-machine-watch.sh` — still 40/0.
- `ainish-rag --context` orientation no longer reports the merged task as `implementing`.
