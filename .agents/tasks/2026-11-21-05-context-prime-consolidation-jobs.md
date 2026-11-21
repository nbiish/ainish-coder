2026-11-21-05-context-prime-consolidation-jobs
# Task: the context call consolidates before it primes, jobs are tracked, research is complete

- lane: now
- branch: `feat/context-prime-consolidation-jobs`
- status: implementing
- plan: `.agents/plans/2026-11-21-05-context-prime-consolidation-jobs.md`
- scope: `src/context/engine.py`, `src/context/context_harness.py`, `.agents/jobs/`,
  `src/deploy_rules_sync.sh`, `src/machine_watch.sh`, `src/machine_sync.sh`,
  `research/context-priming-master/`, `AGENTS.md`, `scripts/test-pqc-dist.sh`
- objective: One `--context` call should consolidate the record through the specialist pair, review it,
  and emit a superior prime; recurring agentic automation needs a tracked `.agents/jobs/` home; and the
  six named research sources must actually be captured rather than cited.

## Findings that shape the work

- **Consolidation is not in the context path.** `run_context_command` never calls it; it is a manual
  verb. Comms is 14 originals / 0 digests, tasks 14/1, plans 18/1 — three folders over the cap.
- **`.agents/jobs/` does not exist.** There is no tracked home for harness, profile, prompt, cadence.
- **Two of the six named sources were never captured.** The EGM plugin repo (291 files, ten canonical
  reviewer personas) and its announcement blog (2026-10-22) — both now fetched.
- **The fourth URL was truncated** in the request (`XaJi7a0U`); it is the already-captured
  `XaJi7a0UChs` transcript.
- **The plugin's persona material is better than our goldfish prompt.** It prescribes paraphrase-first
  review, severity levels, and a self-containment check — the paraphrase step catches documents whose
  parts do not connect even when every term is defined.
- **The watcher is failing 2:1** (50 ok / 96 failed) and `watch.state` reports `failed=0`. The other
  agent's `2026-11-21-00-fleet-sync-reliability.md` diagnoses this; its four fixes are adopted here
  because a broken watcher undermines the whole fleet.

## Next action

T1: capture the sources and correct the dossier.
