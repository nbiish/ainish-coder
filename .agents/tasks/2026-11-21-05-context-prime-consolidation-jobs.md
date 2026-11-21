2026-11-21-05-context-prime-consolidation-jobs
# Task: the context call consolidates before it primes, jobs are tracked, research is complete

- lane: now
- branch: `feat/context-prime-consolidation-jobs`
- status: done (440 assertions pass; merged as `a22f3c8`)
- plan: `.agents/plans/2026-11-21-05-context-prime-consolidation-jobs.md`
- scope: `src/context/engine.py`, `.agents/jobs/`, `bin/ainish-coder`, `src/machine_watch.sh`,
  `src/machine_sync.sh`, `research/context-priming-master/`, `AGENTS.md`, `scripts/test-pqc-dist.sh`
- objective: One `--context` call consolidates the record through the specialist pair and emits a
  superior prime; recurring agentic automation has a tracked `.agents/jobs/` home; and the six named
  research sources are captured rather than cited.

## What changed

| Was | Now |
|---|---|
| consolidation was a manual verb, never in the context path | the call spawns it in the background **before** the learning pass, gated on need, throttled 24h, reported as `provenance.harness.consolidate` |
| no `.agents/jobs/` | index + template + three real records (sync-fleet, consolidate-record, learn-harness), distributed by `--rules`, never overwriting a target's own |
| dossier claimed four sources, two were never captured | six sources named, each with a captured file; ten canonical EGM reviewer personas vendored |
| goldfish comprehension had no coherence test | paraphrase-as-a-test: an unparaphrasable section IS the finding |
| `watch.state` written non-atomically, and `failed=0` written at startup | atomic write; startup says "no cycle has completed yet"; `--status` prints the note |
| `--auto-commit` authored as the operator | `Nanoboozhoo - embodied by {machine}` |

## Findings

1. **Consolidation was never in the context path.** The operator's "one command" description was
   aspirational; the code required two.
2. **Two of six research sources were missing.** The EGM plugin repo carries ten canonical reviewer
   personas — including the paraphrase-first rule, which is the sharpest technique in any source.
3. **`failed=0` came from a startup write**, before any cycle had run, so a reader could not distinguish
   a clean cycle from one that never completed.
4. **`--auto-commit` used the operator's git identity**, a direct contract violation.

## Verification

- `scripts/test-pqc-dist.sh` — **440 assertions pass** (434 baseline, 6 new).
- Live `--context`: `consolidate: {spawned: True, reason: 'over cap: memories, comms, tasks, plans'}`,
  then correctly throttled on the following call.
- `AGENTS.md` — 159 lines (gate is `<= 160`), re-signed, chain verified at 66 transitions, re-locked.
- `--machine-watch --status` works; the scratch-repo test proved the auto-commit identity override.

## Not done, stated plainly

- **The watcher has not been restarted**, so it is still running the code from before these fixes. That
  is an operator action; the new `watch.state` keys (`started=`, `note=`) are how to confirm the restart
  took.
- **A partially-digested period still writes a digest.** `tasks` covered 1 of 16 records because one
  chunk failed review. Recorded in the suggestions file with three options.
- **`.agents/jobs/` is inert and not indexed.** Deliberate: the operator asked for no configuration
  beyond the schema and distribution.
