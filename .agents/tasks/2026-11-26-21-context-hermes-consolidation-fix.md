# Task: Fix `ainish-coder --context` Background Hermes Consolidation Pipeline

- lane: now
- branch: `feat/egm-pair-runtimes-and-consolidation-sweep` (folded into PR #19; 0 commits behind `origin/main`)
- worktree: `/Users/nbiish/code/ainish-coder-worktrees/feat-egm-pair-runtimes-consolidation`
- status: done
- plan: `.agents/plans/2026-11-26-21-context-hermes-consolidation-fix.md`
- scope: `src/context/engine.py`, `bin/ainish-coder`, `src/help.sh`, `llms.txt`, `src/context/tests/test_context_injection.py`, coordination records
- compat: backwards-compatible CLI and digest format (`ainish/context-digest/v1` adds optional `profiles:` / `transports:` YAML frontmatter); adds `--context-consolidate` flag to `bin/ainish-coder` and `--background` to `context-consolidate`
- objective: Update and fix `ainish-coder --context {input}` background logic so it actually utilizes the four specialized consolidating Hermes agent profiles (`consolidate-elephant`, `consolidate-goldfish`, `consolidate-archivist`, `consolidate-structural`) to clean up `.agents/{comms,memories,plans,suggestions,tasks}` down to the three most recent originals plus one rolling digest.

## Root Causes Fixed (2026-11-26)

1. **Hermes `AGENTS.md` hijacking & missing flags:** `hermes_profile_call` omitted `--ignore-rules`, so running inside any repo with `AGENTS.md` made `consolidate-elephant` emit raw JSON bash tool calls to run `ainish-coder --context` (measured live: 3,716 input tokens, 17.4s, rejected every time). `consolidation_call` also omitted `model=HERMES_DEFAULT_MODEL`, leaving Hermes with `"model": ""` against stale `model.base_url` / `key_env` in profile YAML. Now `consolidation_call` passes `--ignore-rules`, `-s <profile>`, and `--provider local-router -m local-router/fallback-models` (overridable via `AINISH_CONSOLIDATE_MODEL`). `_upsert_hermes_config_yaml` strips stale `model.{base_url,key_env,api_mode}` keys and `run_context_setup` marks the three consolidation reviewer profiles `stateless=True`.
2. **Drafter vs coherence prompt tension:** Live smoke #1 caught `consolidate-elephant` inventing causal links to satisfy `coherence`, causing `fidelity` + `coherence` to reject both attempts. Tightened `_digest_prompt`, `CONSOLIDATE_PANEL` (`consolidate-structural`), and retry feedback so the drafter opens with a concise period overview and connects items only when sources record a relationship.
3. **Rolling digest compaction & chronological sorting:** `folder_census` now sorts by `(YYYY, MM, DD, HH_or_-1, name)` so hour-stamped `2026-11-25-22-memory.md` sorts newer than legacy `2026-11-25-memory.txt`, and flags `needs_consolidation` whenever `candidates` exist OR `digests > 1`. `run_context_consolidate` folds aged originals + prior `DIGEST-*.md` files into one verified rolling digest and unlinks covered originals + superseded digests only after unanimous panel approval and write verification.
4. **Lock race, stale locks, & background observability:** `run_context_command` defers `spawn_autolearn` when `spawn_consolidate` spawns so both children cannot race for `.learn.lock`. Added `_reclaim_stale_lock` (dead PID only; live PIDs never stolen), `--background` mode for `context-consolidate`, `.agents/rag/consolidate-last-run.json` status persistence (surfaced in `spawn_consolidate` provenance), and `bin/ainish-coder --context-consolidate`.

## Verification Evidence (2026-11-26)

- `python3 -m py_compile src/context/engine.py src/context/tests/test_context_injection.py` + `bash -n bin/ainish-coder src/help.sh`: pass.
- `AINISH_RAG_NO_PQC=1 python3 -m unittest src/context/tests/test_context_injection.py`: **124 tests OK** (7 new tests added covering Hermes consolidation flags, stale YAML cleanup, chronological sort, rolling digest compaction, fail-closed preservation, dead-PID lock reclamation, and autolearn deferral).
- `AINISH_RAG_NO_PQC=1 python3 -m unittest discover -s src/context/tests -p "test_*.py"`: **173 tests, 3 pre-existing failures** (`test_shared_rules_file_is_loaded_and_strip_ansi`, `test_generation_refuses_to_clobber_a_vault`, `test_wikilinks_survive_a_refused_run` — identical to `main` baseline of 158/3).
- `AINISH_RAG_NO_PQC=1 bash bin/ainish-coder --context-consolidate --dry-run --folder memories --json`: exit 0, `cap: 3`, hour-stamped files protected ahead of legacy `2026-11-25-memory.txt`, 4 prior digests + 11 aged originals planned into single `DIGEST-memories-02.md`.
- Live end-to-end Hermes smoke in isolated scratch repo (containing real `AGENTS.md`, 5 originals, 2 stale digests, `llms.txt`): exit 0, `call_count: 4` (unanimous first-attempt pass across `consolidate-elephant`, `consolidate-goldfish`, `consolidate-archivist`, `consolidate-structural`), `transports_used: ["hermes"]`, `degraded_calls: []`, `originals_after: 3`, `digests_after: 1`, `consolidate-last-run.json` `status: "ok"`, subsequent `spawn_consolidate` reports `spawned: false, folders_needing: []`.

## Deliberately Not Done

- Did not mutate `~/.hermes/` directly from this worktree; runtime CLI flags (`--ignore-rules -s <profile> --provider local-router -m local-router/fallback-models`) work immediately without touching host profiles, and running `ainish-coder --context-setup --group consolidate` will clean stale `model.*` keys on disk.
- Did not delete/consolidate this repository's live `.agents/` records inside this code-fix PR (keeps PR #19 diff scoped and avoids conflicts with dirty files on `main`).
- Did not self-merge PR #19 (`no-rebuild-needed`; delivery is by PR after human approval).
