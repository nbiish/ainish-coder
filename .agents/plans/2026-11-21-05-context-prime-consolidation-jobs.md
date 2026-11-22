---
plan_format: ainish/plan/v1
slug: context-prime-consolidation-jobs
date: 2026-11-21
status: done
branch: feat/context-prime-consolidation-jobs
worktree: /Users/nbiish/code/context-prime-consolidation-jobs
task_record: .agents/tasks/2026-11-21-05-context-prime-consolidation-jobs.md
operator: direct-instruction
---

# Plan: the context call consolidates before it primes, jobs are a tracked surface, and the research is complete

## 1. Problem

Three things are missing from the system the operator described.

**The prime does not consolidate.** `context-consolidate` is a manual verb. A `--context` call reads
the folders as they are, so `.agents/{comms,memories,suggestions,tasks,plans}` accumulate — comms is 14
originals with 0 digests, tasks 14 with 1 — and the prime spends its budget on raw history the pair
could have distilled. The operator's description is that ONE command should consolidate the record,
review it, and emit a masterfully crafted prime.

**There is no `.agents/jobs/`.** Recurring agentic automation — which harness, which profile, which
prompt, which tooling — has no tracked home and no `--rules` distribution.

**The research corpus is incomplete.** The dossier cites four sources; the operator named six. The
Elephant-Goldfish plugin repo and its announcement are not captured at all, and the plugin carries ten
canonical reviewer personas that our goldfish does not draw on.

Separately, the fleet watcher is failing 2:1 (50 ok / 96 failed) and `watch.state` reports `failed=0`;
the other agent's plan covers that and is adopted below rather than duplicated.

## 2. Anchor Facts

- `context-consolidate` exists as a verb; nothing in `run_context_command` calls it — grep of
  `run_context_command` shows no `CONSOLIDAT` reference.
- Folder state now: comms 14 originals/0 digests, memories 8/3, suggestions 4/1, tasks 14/1, plans 18/1.
  Five folders, three of them over the 5 cap.
- `.agents/jobs/` does not exist.
- `research/context-priming-master/sources/` held 3 files (arxiv + two transcripts). The dossier's
  `01-source-extraction.md` says "Four sources were supplied", and the fourth is the harness2 REPO,
  documented in `02-harness2-mechanics.md` rather than stored as a source.
- The operator's `watch?v=XaJi7a0U` is the video already captured as `XaJi7a0UChs` — the id was
  truncated in the request; the transcript is present and matches.
- `github.com/google/elephant-goldfish-model` returns 200 and is real: *"Open-source plugin for
  designing and reviewing software with agents."* 291 files, including `agents/*.md` canonical personas.
- The blog post (`2026-10-22`) is real and states the model's framing: "Design is the new code",
  context collapse, slop, Elephant = context-rich design session, Goldfish = stateless reviewers.
- Ten canonical personas fetched (~40KB) into `sources/egm-plugin/persona-*.md`.
- `watch.log`: **50 `Z ok:` / 96 `Z failed:`**; `watch.state` says `failed=0` while the log disagrees.
- Existing plans: `2026-11-21-00-fleet-sync-reliability.md` (unstarted, branch has 0 commits) and
  `2026-11-20-21-machine-sync-fleet-hardening.md`.

## 3. Plan

### Goals

- A `--context` call consolidates the record **before** it assembles the prime, when the folders are
  over cap and the throttle allows — as a detached pass, so the prime is never delayed.
- `.agents/jobs/` exists, is distributed by `--rules`, and records what an automation is: harness,
  profile, prompt, cadence, tooling, and what it is for. No further configuration.
- All six named sources are captured, and the dossier says what each contributes.
- The goldfish reviewer draws on the canonical persona material (paraphrase-first, severity levels,
  self-containment) instead of an ad-hoc prompt.
- The fleet-sync plan's watcher defects are fixed, since a failing watcher undermines everything above.

### Non-goals

- Configuring jobs beyond the schema and distribution. The operator was explicit.
- Replacing the consolidation pair. It works; this plan wires it into the call.
- Making consolidation synchronous in the prime path.

### Constraints and invariants

- The prime is assembled from what exists at call time; consolidation may only happen before assembly
  or after it, never during.
- A consolidation failure never blocks the prime.
- `AGENTS.md` stays at 160 lines.
- `.agents/jobs/` records are data, not code; nothing in it executes.

### Proposed architecture

```
ainish-coder --context "<task>"
  ├─ orientation → retrieval → elephant → goldfish     (unchanged)
  ├─ assemble the prime                                ← the agent's answer ends here
  └─ spawn detached passes (throttled, locked, one at a time):
        consolidate  — when a folder is over cap and a period is undigested
        learn        — the existing tuning pass
```

### Interfaces and data

- `.agents/jobs/<name>.md` — frontmatter: `name`, `harness`, `profile`, `prompt`, `cadence`,
  `tooling`, `purpose`, `status`; body: what it does and how to run it by hand.
- `.agents/jobs/llms.txt` — the index, distributed by `--rules`.
- `spawn_autolearn(..., jobs=("consolidate","learn"))` — one throttle, one lock, ordered so
  consolidation runs before tuning (a smaller corpus tunes better).
- `AINISH_CONSOLIDATE_ON_CONTEXT` (default on) and `AINISH_CONSOLIDATE_INTERVAL_S`.

### Files and symbols

- `src/context/engine.py` — `spawn_autolearn` gains the consolidation pass; `run_context_command`
  unchanged in its synchronous path; `_goldfish_system_prompt` rewritten from the persona material.
- `src/context/context_harness.py` — throttle state per pass.
- `.agents/jobs/` — `llms.txt`, `sync-fleet.md`, `consolidate-record.md`, `learn-harness.md`, and a
  template.
- `src/deploy_rules_sync.sh` / `bin/ainish-coder` — distribute `.agents/jobs/`.
- `research/context-priming-master/01-source-extraction.md` — six sources, corrected.
- `src/machine_watch.sh`, `src/machine_sync.sh` — the four watcher fixes from the fleet-sync plan.
- `scripts/test-pqc-dist.sh` — assertions for each.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Consolidate inside the prime, synchronously | Would delay every call by minutes; the contract says a context call must never block |
| Auto-configure jobs from the harness | Operator explicitly said no configuration beyond the schema |
| Keep the four-source dossier | Two named sources are missing and one is the plugin whose personas we now use |
| Leave the watcher to its own plan | It is failing 2:1 and writing an untrue state file; shipping around it would be a silent downgrade |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Background consolidation deletes records unexpectedly | The pair's gate; a dry-run mode; the throttle; `.agents/` is committed so git restores |
| Jobs become a place agents put executable content | Frontmatter is data; nothing in jobs is run; the loader reads it, never sources it |
| Rewriting the goldfish prompt regresses the prime | A/B the readiness verdict on three real tasks before and after |
| Watcher changes destabilise a working sync | Each of the four fixes ships with its own assertion |

## 4. Clarifications

### 4.1 Whether consolidation runs from the context call

- **Question:** You said the context call should consolidate. Synchronously (slower but guaranteed) or detached (fast, best-effort)?
- **Selected:** detached, throttled, before the learning pass — the same shape the learning pass already uses, since the contract forbids blocking.
- **asked:** resolved from code (`spawn_autolearn` established the pattern and the constraint).

### 4.2 How much of the research to ingest

- **Question:** The plugin has 291 files. All of it, or the reviewer personas and the framing?
- **Selected:** the two missing sources in full, plus the ten canonical personas; the workflow files are read for mechanics but not vendored wholesale.
- **asked:** resolved from code (the dossier's own weighting: mechanism over volume).

## 5. Todos

- [x] **T1** Capture the two missing sources and the ten personas; correct the dossier to six.
  - from: §4.2 | done when: `01-source-extraction.md` lists six and each has a file | verify: ls + grep
- [x] **T2** Rewrite the goldfish system prompt from the persona material (paraphrase-first, severity, self-containment).
  - from: §3 | done when: the prompt carries the paraphrase step and severity levels | verify: grep + a live review
- [x] **T3** Create `.agents/jobs/` with schema, index, three real jobs, and a template.
  - from: §3 | done when: the four files exist and are indexed | verify: ls
- [x] **T4** Distribute `.agents/jobs/` from `--rules`.
  - from: §3 | done when: a scratch deploy carries the folder | verify: deploy then ls
- [x] **T5** Spawn consolidation from the context call, throttled and ordered before learning.
  - from: §4.1 | done when: an eligible call spawns it and a throttled call does not | verify: provenance
- [x] **T6** Fix the watcher: per-repo backoff, quarantine, honest `watch.state`, machine identity for auto-commit.
  - from: §3 | done when: one failing repo does not delay another, and the state file matches the log | verify: scripted
- [x] **T7** Update AGENTS.md, help, and the suite.
  - from: §3 | done when: 160 lines and the suite passes above 434 | verify: both

## 6. Verification

- `scripts/test-pqc-dist.sh` — passes above 434 assertions.
- `wc -l < AGENTS.md` — 160.
- A context call on an over-cap folder reports `consolidate.spawned: true`; a second call within the
  interval reports why not.
- A scratch `--rules` deploy contains `.agents/jobs/` with its index.
- `01-source-extraction.md` names six sources, each with a captured file.
- `watch.state` `failed` count matches the log for the last cycle.

## 7. Open Decisions

- Whether jobs should ever be executed by the tooling or only documented — settled by whether an
  operator asks for one to run.
- The consolidation interval — settled by how often a folder actually crosses the cap.
