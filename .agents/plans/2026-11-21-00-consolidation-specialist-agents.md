---
plan_format: ainish/plan/v1
slug: consolidation-specialist-agents
date: 2026-11-21
status: ready
branch: feat/consolidation-specialist-agents
worktree: /Users/nbiish/code/consolidation-specialist-agents
task_record: .agents/tasks/2026-11-21-00-consolidation-specialist-agents.md
operator: direct-instruction
---

# Plan: consolidation gets its own specialized agent pair, and a gate that blocks

## 1. Problem

Consolidation was built using the SAME `elephant` and `goldfish` roles that produce the context prime,
with no separate skill, no separate model, and an ADVISORY review. A live test across all five folders
produced 7 digests and left **91 originals** — every folder still over its cap — and introduced two
regressions into the prime itself. Worse, the first real run deleted 16 files to replace them with a
one-line preamble, because a non-empty check passed a model's "I'll start by…".

The operator's design is a **compartmentalized** pair: dedicated agents with their own skills and memory
that consolidate the records older than the newest three, and check each other's work before anything is
written or removed — separate from the main prime pair, which stays untouched by consolidation.

## 2. Anchor Facts

- `_digest_in_chunks` calls `pi_agent_call(role="elephant", model=_pi_role_model("elephant"))` — the
  same role the prime uses, with the same model and no consolidation-specific prompt file.
- The only check is `_digest_is_usable`: length, 3-of-4 sections, no promise-opener. It is applied to
  the DRAFT before writing; the `goldfish` review happens AFTER and is **advisory** — a timeout still
  writes the digest.
- Measured failure rate of `pi` under sustained load: comms 1 chunk failed, memories 1, plans 3 of 6 plus
  the merge, suggestions merge, tasks **all 6 chunks**. `pi` timed out at 90s, 200s, and 300s on the
  same payload that answered in 5s with a shorter instruction.
- `hermes` is at `/Users/nbiish/.local/bin/hermes`, has 4 profiles all on `mimo-v2.6-pro`, and
  `hermes -z "<prompt>" --profile default` returned `HERMES_OK` in **9s** — faster and more reliable
  than `pi` on this host.
- `hermes profile create <name> --description "<text>"` exists; a profile with no description is
  invisible to the kanban orchestrator (stated in the `specialized-agents` skill).
- Orientation's plan reader takes `status:` from the newest file in `.agents/plans/`. A digest has no
  `status:` field, so `DIGEST-plans-2026-11.md` makes the prime report `status: designing`.
- Orientation's newest task record is the newest `.md` in `.agents/tasks/`, so
  `DIGEST-tasks-2026-11.md` displaces the real record.
- The graph indexes digests (7 DIGEST nodes), which is intended — they must carry the knowledge.
- `specialized-agents` SKILL.md exists under `skills-to-distribute/skills/` and documents the
  discovery/invoke pattern this plan follows.

## 3. Plan

### Goals

- Consolidation runs as a **distinct pair**: `consolidate-elephant` drafts, `consolidate-goldfish`
  checks, both as hermes profiles with their own descriptions and skills.
- The check **blocks**: nothing is written or removed unless it passes. A failed review is a refusal.
- A whole folder cannot be lost to one flaky call: per-chunk artifacts persist, retries back off, and a
  run resumes where it stopped.
- Digests stop corrupting the prime: orientation never reports a digest as the plan of record or the
  newest task.
- Every folder ends at or under 5 originals, or the run says exactly why it did not.

### Non-goals

- Changing the prime's own elephant/goldfish. They are working; the point is to keep consolidation
  out of them.
- Fixing the underlying `pi` instability. Hermes is the transport for this work, with `pi` as fallback.
- Consolidating `research/` or `wiki/`.

### Constraints and invariants

- The three newest records per folder are never read as candidates.
- `llms.txt` and `*.live.*` are never consolidated or counted.
- A digest is written before its sources are removed, and only sources it names are removed.
- `AGENTS.md` stays at 160 lines.
- The contract's fail-closed rule: a review that could not run is a refusal, not a pass.

### Proposed architecture

```
context-consolidate [--folder F] [--dry-run] [--resume] [--json]
  ├─ census: protect newest 3, exclude indexes/sidecars
  ├─ for each period, split into batches that FIT (measured size bound)
  │    ├─ consolidate-elephant  (hermes profile) drafts the digest body
  │    │     write .agents/context-harness/consolidate/<folder>-<period>/chunk-NN.md
  │    └─ consolidate-goldfish  (hermes profile) checks: completeness, fidelity, section shape
  │          PASS  → chunk accepted
  │          FAIL  → chunk retried with the reviewer's named gap; then the PERIOD is abandoned
  ├─ merge accepted chunks (elephant), gate the merge the same way
  ├─ only then: write DIGEST, read back, remove exactly the named sources
  └─ report per folder: originals, digests, over-cap reason
```

### Interfaces and data

- `hermes_profile_call(role, prompt, *, timeout) -> {text, profile, error}` — one place that shells to
  `hermes -z --profile`, mirroring `pi_agent_call`'s never-raise contract, with `pi` as fallback.
- `CONSOLIDATE_ROLES = {"drafter": "consolidate-elephant", "reviewer": "consolidate-goldfish"}`.
- Per-chunk artifacts: `.agents/context-harness/consolidate/<folder>-<period>/chunk-NN.{draft,review,json}`.
- `--resume` reuses an accepted chunk instead of re-drafting it.
- `provenance` reports `consolidation: {transport, drafter, reviewer, gate: pass|refused}`.

### Files and symbols

- `src/context/engine.py` — `hermes_profile_call`, `_consolidate_roles`, `_digest_in_chunks` rewritten to
  per-chunk artifacts + blocking gate, `_digest_draft_prompt`/`_digest_review_prompt` separated,
  `run_context_consolidate` gate wiring, `--resume` flag.
- `src/context/context_harness.py` — `consolidate_state_dir`.
- `scripts/consolidation-skills/consolidate-elephant.md`, `consolidate-goldfish.md` — the profiles' skill
  text, installed by `--rules`.
- `src/deploy_rules_sync.sh` — create the two profiles if absent, set their descriptions, install skills.
- `src/context/engine.py` orientation — skip `DIGEST-*` when choosing the newest task record and plan.
- `AGENTS.md` — one line in *Close* naming the consolidation pair; paid for by trim.
- `scripts/test-pqc-dist.sh` — assertions for the gate, the role separation, digest exclusion, and resume.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Keep `pi` with more retries | Measured: 6 of 6 chunks failed in one folder. Retries alone do not fix a transport that times out on the payload |
| Separate `AINISH_*_MODEL` env vars on the same roles | Roles would still share one prompt surface and one skill set; no compartmentalization |
| Advisory review with a score | Operator chose blocking. A threshold invites tuning the number instead of fixing the digest |
| Rename digests so they sort last | A file-order trick; orientation must exclude them by MEANING, not by name luck |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Hermes profiles drift from the repo's intent | Skills live in the repo and `--rules` re-installs them; the profile is a thin shell |
| A blocking gate makes consolidation refuse forever | Refusal is the right outcome when the pair cannot agree; the report names the gap so the operator can act |
| Digests already written keep corrupting the prime | Fix orientation in the same change and re-verify the prime |
| Resume leaves stale artifacts | Chunk artifacts are keyed on the source file list; a changed set invalidates them |

## 4. Clarifications

### 4.1 The dedicated pair

- **Question:** Consolidation uses the prime's roles. What should the pair be?
- **Options:** 1. (chosen) Hermes profiles with their own descriptions and skills; 2. dedicated pi roles; 3. Agent-SDK subagents.
- **Selected:** 1 — `consolidate-elephant` and `consolidate-goldfish`.
- **Trade-off accepted:** A dependency on hermes existing on the host; `pi` remains the fallback so a host without hermes still works, degraded.

### 4.2 Whether the review blocks

- **Question:** The review is advisory today. Should it block?
- **Options:** 1. (chosen) Blocking; 2. advisory; 3. scored threshold.
- **Selected:** 1.
- **Trade-off accepted:** Some periods will be refused outright. That is correct: a digest that replaces data must be checked by something other than its author.

### 4.3 Transport

- **Question:** One call per period, or chunked?
- **Options:** 1. (chosen) Both — size-bounded single calls on a reliable transport, chunking as the fallback.
- **Selected:** 1.
- **Trade-off accepted:** Two code paths to maintain.

## 5. Todos

- [ ] **T1** Add `hermes_profile_call` with a `pi` fallback and a never-raise contract.
  - from: §4.1 | done when: a call returns text and names which transport served it | verify: a direct call
- [ ] **T2** Add `--rules` provisioning of `consolidate-elephant`/`consolidate-goldfish` with descriptions and skills.
  - from: §4.1 | done when: `hermes profile list` shows both with descriptions | verify: that command
- [ ] **T3** Split the draft and review prompts so the reviewer checks the DRAFT against the sources.
  - from: §4.2 | done when: a deliberately incomplete draft is refused | verify: a constructed fixture
- [ ] **T4** Make the gate blocking, with one retry that carries the reviewer's named gap.
  - from: §4.2 | done when: a failed review leaves the sources in place and records why | verify: suite
- [ ] **T5** Persist per-chunk artifacts and add `--resume`.
  - from: §4.3 | done when: an interrupted run resumes without re-drafting accepted chunks | verify: suite
- [ ] **T6** Exclude `DIGEST-*` from orientation's newest-task and newest-plan selection.
  - from: §3 | done when: the prime reports the real plan and task, not a digest | verify: one context call
- [ ] **T7** Re-run consolidation on all five folders and prove each ends at or under 5 originals.
  - from: §3 | done when: every folder reports ≤5 originals or a named refusal | verify: `context-consolidate`
- [ ] **T8** Update AGENTS.md, help, and the suite.
  - from: §3 | done when: AGENTS.md is 160 lines and the suite passes above 426 | verify: both

## 6. Verification

- `scripts/test-pqc-dist.sh` — passes above 426 assertions.
- `wc -l < AGENTS.md` — 160.
- `hermes profile list` — both consolidation profiles present, described.
- A context call reports the real newest plan and task, never a `DIGEST-`.
- After a full run: `find .agents/<folder> -name '2026-*' | wc -l` ≤ 5 per folder, or a recorded refusal.
- A deliberately bad draft is refused and its sources survive.

## 7. Open Decisions

- Whether the pair should keep its own memory across runs (hermes profiles carry memory) so a repeated
  failure is not rediscovered each time — settled after two full runs.
- Whether 5 is the right cap for `tasks/`, which is the largest folder — settled by whether the pair can
  reliably digest 40+ records at that granularity.
