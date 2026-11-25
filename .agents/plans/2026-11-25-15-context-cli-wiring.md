---
plan_format: ainish/plan/v1
slug: context-cli-wiring
date: 2026-11-25
status: done
branch: fix/context-cli-wiring
worktree: /Users/nbiish/code/ainish-coder-worktrees/fix-context-cli-wiring
task_record: .agents/tasks/2026-11-25-15-context-cli-wiring.md
operator: omp
---

# Plan: Wire the documented `ainish-coder --context-*` self-improvement verbs and make the prime's gate line truthful

## 1. Problem

The `ainish-coder --context {input}` pipeline (context priming/querying with elephant/goldfish advice
over `.agents/`, served through local-router's fallback chain) was verified end-to-end and works. Two
surface defects remain. First, the engine's own help advertises five self-improvement verbs
(`ainish-coder --context-seed/-status/-learn/-rollback/-promote`) but the launcher's dispatch has no
case for them: they fall through to `Unknown command`, so the documented loop over
`.agents/context-harness/` is unreachable from the CLI every agent is told to use. Second, the
orientation section of the prime relays a cached gate verdict without saying which checks it covered:
a prime reported `gate: RED (anchor 100%)` while a live `ainish-context gate` at the same commit is
GREEN, and a stale RED verdict is never marked stale (the staleness guard fires only for GREEN).

## 2. Anchor Facts

- All five engine subcommands `context-seed`, `context-status`, `context-learn`, `context-rollback`,
  `context-promote` exist and parse — established by running `bin/ainish-context <verb> --help` (5/5).
- `bin/ainish-coder` wires only `--context`, `--context-setup`, `--context-engine`, `--rag`;
  `--context-status` returns `Unknown command` — established from `bin/ainish-coder:1025-1115` and a
  live run.
- The engine's `main()` help advertises the verbs as `ainish-coder --context-*` — established from
  `src/context/engine.py` (docstring of `main()`).
- `--context` end-to-end is healthy: full envelope in 76s with all four sections sourced
  (`hermes:context-elephant`/`hermes:context-goldfish` via `local-router/fallback-models`);
  `--retrieval-only` answers in 2.7s with `degraded: false` — established from live runs.
- The orientation gate line reads `.agents/rag/gate-status.json` and marks staleness only when the
  recorded status is GREEN (`src/context/engine.py:6001-6013`); the written schema carries
  `tests.{provided,command,exit_code,pass}`, `branch`, `commit`, `updated_at`
  (`src/context/engine.py:9659-9682`) — established from the source.
- The observed `gate: RED (anchor 100%)` was an honest recorded full-tests verdict (3 pre-existing
  failures documented in the 2026-11-24-21 task record); the line cannot say so — established from
  `/tmp/ctx-full.out` and `.agents/rag/gate-status.json`.
- No test pins the gate-line format — established from `grep` of
  `src/context/tests/test_context_injection.py`.
- The launcher dispatch pattern is `command="$1"; shift` then forward `"$@"` — established from
  `bin/ainish-coder:75-76`.

## 3. Plan

### Goals

- `ainish-coder --context-seed|-status|-learn|-rollback|-promote` work exactly as the engine help
  documents, forwarding all extra flags to the engine subcommand.
- The prime's `- gate:` orientation line tells the truth: a stale verdict is marked stale regardless
  of color, and a recorded verdict that ran tests shows whether tests passed or failed.

### Non-goals

- No change to the `degraded:` budget-ladder semantics (trim notes flipping the flag is by design;
  the notes name the cause).
- No change to gate computation itself (the 3 pre-existing test failures are a known baseline).
- No `AGENTS.md`, hermes, or local-router changes.

### Constraints and invariants

- `scripts/test-pqc-dist.sh` pins exact phrases in shipped help/contract text: the help.sh addition
  must not disturb existing pins (verified by running the suite).
- The launcher is bash; dispatch must handle both `--context-verb` and pass `"$@"` untouched.

### Proposed architecture

One new `case` arm in `bin/ainish-coder` mapping `--context-<verb>` -> `ainish-context
context-<verb> "$@"`, beside the existing `--context-setup` arm. The engine change is confined to the
gate-line builder in the orientation section: compare `commit` to HEAD for any status, and append the
recorded `tests` result when tests were provided.

### Interfaces and data

- CLI: `ainish-coder --context-seed [--json]`, `--context-status [--json]`,
  `--context-learn [--task ... --dry-run|--background|...]`, `--context-rollback <generation>`,
  `--context-promote <name>` — new accepted surface, all previously `Unknown command` (exit 1).
- `gate-status.json` schema unchanged; only the rendering of its fields in the orientation line
  changes (`- gate: RED (anchor 100%, tests failed)` / `- gate: GREEN (anchor 100%) but for commit
  c8cb96a, not HEAD (stale verdict)`).

### Files and symbols

- `bin/ainish-coder` — new `case` arm near `--context-setup`; `_TRACK_DETAIL` = `context-<verb>`.
- `src/help.sh` — AGENT CONTEXT section: one entry listing the five verbs.
- `src/context/engine.py` — orientation gate-line builder (~lines 6001-6013).
- `src/context/tests/test_context_injection.py` — unit coverage for the two gate-line behaviours.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Route the verbs through the existing `--context-engine` passthrough and document that | The engine help already promises `ainish-coder --context-*`; changing the promise rewrites shipped docs instead of fixing the wiring |
| Recompute the gate live inside `--context` | Costs seconds on every prime and duplicates `run_gate`; the cached verdict plus provenance is enough for an agent to judge |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| help.sh edit disturbs dist-suite phrase pins | Run `scripts/test-pqc-dist.sh` in verification |
| Gate-line wording change breaks a consumer parsing the line | No test or script parses it (grep-verified); wording keeps the `- gate: <STATUS>` prefix |

## 4. Clarifications

### 4.1 Scope of the fix

- **Question:** Should the misleading `degraded: true` on healthy trimmed runs and the gate
  nondeterminism (RED-with-tests vs GREEN-without) also be fixed here?
- **Options:** 1. (Recommended) fix wiring + gate-line truthfulness only — bounded, addresses the
  two misleading surfaces; 2. also redesign `degraded:` semantics — larger, and the notes already
  name the cause; 3. also make the gate deterministic across invocation modes — separate design.
- **Selected:** Option 1; report the rest as findings.
- **Trade-off accepted:** `degraded: true` still appears on budget-trimmed runs; the accompanying
  `<!-- degraded: trimmed retrieved tail; ... -->` note carries the reason.
- **asked:** resolved from code
- **resolved by:** `src/context/engine.py:5840-5889` (explicit degradation ladder) and
  `.agents/rag/gate-status.json` `tests` field semantics.

## 5. Todos

- [x] **T1** Add the `--context-{seed,status,learn,rollback,promote}` case arm to `bin/ainish-coder`.
  - from: §1 | done when: all five flags reach the matching engine subcommand | verify: `bash bin/ainish-coder --context-status </dev/null` prints the harness state
- [x] **T2** Document the five verbs in the AGENT CONTEXT section of `src/help.sh`.
  - from: §1 | done when: `bash bin/ainish-coder --help` lists them | verify: `grep -c 'context-learn' <(bash bin/ainish-coder --help)`
- [x] **T3** Make the orientation gate line mark staleness for any colour and include the recorded tests result.
  - from: §1 | done when: stale RED renders `(stale verdict)`, tests-failed renders `tests failed` | verify: unit tests
- [x] **T4** Add unit coverage in `test_context_injection.py` for T3.
  - from: §3 | done when: new assertions pass | verify: `python3 -m unittest src/context/tests/test_context_injection.py -k Orientation -v`

## 6. Verification

- `bash -n bin/ainish-coder src/help.sh` — exit 0.
- `python3 -m py_compile src/context/engine.py` — exit 0.
- Smoke each new flag through `bin/ainish-coder` (5/5 reach the engine).
- `python3 -m unittest src/context/tests/test_context_injection.py -v` — all pass.
- `python3 -m unittest src/context/tests/test_gate_ready.py` — `test_shared_state_is_append-only`
  pass; 3 documented pre-existing failures unchanged from `main`.
- `PQC_CONFIG_DIR=<tmp> PQC_STORE_ISOLATED=1 bash scripts/test-pqc-dist.sh </dev/null` — 0 failed.

## 7. History

- 2026-11-25 created from the tooling verification session (operator: "ensure our tooling is working
  as intended"); the `--context` pipeline itself verified healthy, this plan covers the two surface
  defects the verification exposed.
