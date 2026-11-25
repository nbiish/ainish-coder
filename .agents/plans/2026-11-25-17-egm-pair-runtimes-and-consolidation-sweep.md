---
plan_format: ainish/plan/v1
slug: egm-pair-runtimes-and-consolidation-sweep
date: 2026-11-25
status: done
branch: feat/egm-pair-runtimes-and-consolidation-sweep
worktree: /home/nanoboozhoo/code-external/ainish-coder-worktrees/feat-egm-pair-runtimes-and-consolidation-sweep
task_record: .agents/tasks/2026-11-25-17-egm-pair-runtimes-and-consolidation-sweep.md
operator: nanoboozhoo
---

# Plan: EGM Pair Runtimes (Elephant = Hermes profile, Goldfish = Pi agent) and Every-Run Consolidation Sweep

## 1. Objective

Operator's architecture, stated 2026-11-25:

1. **Prime pair on the Elephant-Goldfish Model with pinned runtimes.** The elephant runs on a
   specified Hermes profile (`context-elephant`, overridable via `AINISH_CONTEXT_ELEPHANT_PROFILE`);
   the goldfish is a Pi agent (`pi` runtime, model pin `AINISH_RAG_GOLDFISH_MODEL` honoured as today).
   Degraded fallbacks stay EXPLICIT with recorded `degrade_note`s — never a silent downgrade.
   Their outputs concatenate into the context prime on **every** `ainish-coder --context` call.
2. **A `skip_retrieval` route skips corpus retrieval ONLY, never the pair.** Today the measured
   symptom (operator's paste, 2026-11-25): a skip route starved elephant/goldfish entirely and
   flagged the envelope `degraded: true` for a deliberate design choice. The route note moves to
   provenance (`route_note`, rendered `<!-- route: ... -->`); a deliberate skip is no longer
   "degraded".
3. **Consolidation sweeps every context run.** The specialized Hermes consolidation agents
   (`consolidate-elephant` drafter + `consolidate-goldfish` / `consolidate-archivist` /
   `consolidate-structural` panel) manage `.agents/` context folders every time the context agent
   runs: an every-run verification census of all five folders, a background sweep-and-condense of
   every folder with records beyond the protected three, maintaining the **three most recent files
   of each context folder** (`CONSOLIDATION_PROTECTED_NEWEST = 3`) in original form.
4. Insights at closeout fold back into the tooling (code comments/docs) and durable `.agents/`
   records.

## 2. Threat model & constraints

- **Assets:** `.agents/` coordination history — consolidation DELETES originals and the digest is
  the only surviving copy; the operator's context quality; PQC secrets bundle (untouched).
- **Controls:**
  - Digest-before-delete order is preserved: digest written, re-read, `_digest_is_usable` gate,
    then unlink of exactly the files the `sources:` list names. The three newest records per folder
    are never read as candidates (`folder_census`), computed from the record date in the filename.
  - Goldfish isolation is structural: no session parameter, no access to the elephant session
    sidecar; `goldfish_review`'s signature unchanged.
  - No secrets in prompts, profile blueprints, or tests. Tests are deterministic and offline:
    transports and `subprocess.Popen` are stubbed; no network, no model calls.
  - Envelope format (`CONTEXT_FORMAT`) unchanged: no new section kinds; route note is a comment
    line, not a section.
  - `AGENTS.md` and `LICENSE` untouched.
- **Tradeoff accepted (operator's call):** the pair now spends its model calls on every non
  `--retrieval-only` context run, including tasks the router judged self-contained. The
  `AINISH_CONSOLIDATE_INTERVAL_S` knob (default becomes 0 = every run) remains for operators who
  want to throttle the consolidation spawn; the lock still prevents pile-on.

## 3. Change surface

- `src/context/engine.py`
  - `_context_agent_call`: role-tier table — `elephant: hermes → pi → driver`,
    `goldfish: pi → driver` (auto mode). Explicit `AINISH_CONTEXT_RUNTIME` still wins for both
    roles (an operator override is the operator's word). `context-goldfish` stays provisioned by
    `--context-setup` (doctor parity) and reachable only through an explicit hermes override.
  - `run_context_command`: dispatch the pair whenever `not retrieval_only`, regardless of
    `skip_retrieval`; move the route-skip note from `degrade_notes` to
    `provenance["route_note"]`; `degraded` no longer set by a deliberate skip.
  - `spawn_consolidate`: every-run synchronous verification census of all five folders, written to
    `.agents/context-harness/consolidate-sweep.json`; spawn `context-consolidate` (all folders)
    whenever any folder has records beyond the protected three; interval env default 0; the spawn
    result + verification ride in provenance (`harness.consolidate`).
  - `CONSOLIDATION_DEFAULT_CAP = CONSOLIDATION_PROTECTED_NEWEST` — steady state is three originals
    plus digests per folder, matching "maintaining the three most recent files".
- `src/context/tests/test_context_injection.py`
  - Rewrite `test_skip_retrieval_route_emits_no_filler_and_no_driver_spend` to the new contract
    (no retrieval filler; the pair runs and concatenates; route note in provenance; not degraded).
  - New: goldfish dispatches pi first and never consults hermes in auto mode; goldfish degrades
    pi → driver with a recorded note; sweep verifies all folders and condenses only beyond the
    protected three; `run_context_consolidate` keeps exactly the three newest records.
- `src/help.sh`, `llms.txt`: document the pair runtimes and the every-run sweep.

## 4. Verification

- `python3 -m unittest discover -s src/context/tests -p "test_*.py"` — run FIRST for a baseline;
  known pre-existing failures (`test_wiki_graph.py`, `test_gate_ready.py`,
  `RoleModelSeparationTest`) are reported with their baseline, not chased.
- Live smoke on a scratch repo: `bin/ainish-coder --context "<skip-routed task>" --json` shows
  `elephant` + `goldfish` sections in order, `route_note` in provenance, `degraded: false`, and the
  consolidation sweep report listing all five folders.

## 5. Delivery

Worktree off latest `origin/main`, branch `feat/egm-pair-runtimes-and-consolidation-sweep`, atomic
Conventional Commits, PR to `main` with What / Why / How verified. Never self-merge. Closeout:
task record, today's COMMS ledger, scrubbed memory facts, suggestions for findings that outlive
the task.
