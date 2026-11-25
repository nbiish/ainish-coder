# Task: Wire documented `ainish-coder --context-*` self-improvement verbs and truthful gate line

- lane: now
- branch: `fix/context-cli-wiring`
- worktree: `/Users/nbiish/code/ainish-coder-worktrees/fix-context-cli-wiring`
- status: done
- plan: `.agents/plans/2026-11-25-15-context-cli-wiring.md`
- scope: `bin/ainish-coder`, `src/help.sh`, `src/context/engine.py`, `src/context/tests/test_context_injection.py`
- compat: additive and backward-compatible — adds five launcher flags that were documented but
  rejected (`Unknown command`), and enriches the orientation `- gate:` line (same prefix, more
  provenance); no schema, signature, or exit-code change on any existing surface.
- objective: Make the self-improvement loop over `.agents/context-harness/` reachable exactly as the
  engine help documents (`ainish-coder --context-{seed,status,learn,rollback,promote}`) and make the
  prime's cached gate verdict self-describing (stale marked for any colour, tests result shown).

## Verification & Closeout Evidence

- `bash -n bin/ainish-coder src/help.sh` + `python3 -m py_compile src/context/engine.py
  src/context/tests/test_context_injection.py`: pass (exit 0)
- Smoke through `bin/ainish-coder`: 5/5 flags (`--context-seed|-status|-learn|-rollback|-promote`)
  reach the matching engine subcommand; `--context-status` prints the live harness state
  (generation 0, 6 staged skills, 3 rejected); `--help` lists all five (5 matches).
- `python3 -m unittest src/context/tests/test_context_injection.py`: **109/109 pass** (106 prior +
  3 new: stale-RED marked stale, recorded tests result shown, plain form preserved).
- `python3 -m unittest src/context/tests/test_gate_ready.py`: `test_shared_rules_file_is_loaded_and_strip_ansi`
  fails — identical on the untouched `main` checkout (pre-existing baseline).
- `python3 -m unittest src/context/tests/test_wiki_graph.py`: 2 failures
  (`test_generation_refuses_to_clobber_a_vault`, `test_wikilinks_survive_a_refused_run`) — the
  documented pre-existing baseline (2026-11-24-21), unchanged.
- `PQC_CONFIG_DIR=<tmp> PQC_STORE_ISOLATED=1 bash scripts/test-pqc-dist.sh </dev/null`:
  **PASS: 457 assertions, 0 failed** (help.sh addition disturbs no phrase pins).
- Context-tooling verification (the session that produced this task): `ainish-coder --context` full
  envelope in 76s with all four sections sourced through `local-router/fallback-models`
  (`hermes:context-elephant`/`hermes:context-goldfish`), `--retrieval-only` in 2.7s, live
  `ainish-context gate` GREEN; the envelope's `gate: RED (anchor 100%)` was a recorded full-tests
  verdict (3 pre-existing failures) that this task's gate-line change now makes self-describing.
- Rebuild verdict: `no-rebuild-needed` (repo ships no long-running server).
