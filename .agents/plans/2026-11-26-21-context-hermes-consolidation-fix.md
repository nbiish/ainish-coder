---
plan_format: ainish/plan/v1
slug: context-hermes-consolidation-fix
date: 2026-11-26
status: done
branch: feat/egm-pair-runtimes-and-consolidation-sweep
worktree: /Users/nbiish/code/ainish-coder-worktrees/feat-egm-pair-runtimes-consolidation
task_record: .agents/tasks/2026-11-26-21-context-hermes-consolidation-fix.md
integration: fold-into:PR#19
operator: nanoboozhoo
---

# Plan: Fix `ainish-coder --context` Background Hermes Consolidation Pipeline

## 1. Objective

Fix the `ainish-coder --context {input}` background consolidation pipeline so it reliably utilizes the four specialized Hermes consolidation profiles (`consolidate-elephant` drafter + `consolidate-goldfish` / `consolidate-archivist` / `consolidate-structural` panel) to condense `.agents/{comms,memories,plans,suggestions,tasks}` down to the three most recent original files plus one rolling panel-verified digest — preventing agents from ingesting outdated, unnecessary, or repeated content.

Integrated into open PR #19 (`feat/egm-pair-runtimes-and-consolidation-sweep`, 0 commits behind `origin/main`, which already ships the every-run sweep and `CONSOLIDATION_DEFAULT_CAP = 3`).

## 2. Threat Model & Constraints

- **Assets:** `.agents/{comms,memories,plans,suggestions,tasks}` coordination history (consolidation deletes originals and superseded digests after writing a new digest); context prime quality; PQC secrets store (untouched).
- **Worst realistic outcome:** An unusable digest, unverified draft, or wrong filename sort deletes recent/active records or loses unresolved threads permanently outside git history; or a background race/stale lock silently wedges consolidation indefinitely.
- **Controls:**
  - Digest-before-delete remains strictly enforced in code: `_digest_is_usable` + unanimous 3-member Hermes panel (`VERDICT: pass`) + write and read-back size > 0 BEFORE any `unlink()`.
  - Protected retention is strictly enforced in code: `CONSOLIDATION_PROTECTED_NEWEST = 3` chronological newest originals (`(YYYY, MM, DD, HH_or_-1, name)` sort), `llms.txt`, and `*.live.*` sidecars are never candidates and never unlinked.
  - Prior `DIGEST-*.md` files are rolled into the new digest and unlinked ONLY when included in the verified `covered` set and NEVER the newly written digest itself.
  - No secrets in prompts, configs, logs, or tests. `AGENTS.md` and `LICENSE` untouched.
  - Unit tests remain offline and deterministic (Hermes/Pi/`Popen` stubbed); live verification runs in an isolated scratch repo with real Hermes profiles.

## 3. Root Causes Found (Measured 2026-11-26)

1. **Hermes `AGENTS.md` contamination & missing skill/model flags (`hermes_profile_call` + `consolidation_call`):**
   - Running `hermes --profile consolidate-elephant chat ...` inside a repo without `--ignore-rules` auto-injected `AGENTS.md`, causing the consolidation agent to output raw JSON tool calls (`{"tool_calls": [{"name": "bash", "arguments": {"cmd": "ainish-coder --context ..."}}]}`) instead of a digest (measured: 3,716 input tokens, 17.4s, rejected every time).
   - `consolidation_call` omitted `model=HERMES_DEFAULT_MODEL`, so Hermes got no `--provider local-router -m local-router/fallback-models` and hit stale `model.base_url` / `model.key_env` left behind in profile `config.yaml` (`"model": ""`).
   - Passing `--ignore-rules -s <profile> --provider local-router -m local-router/fallback-models` verified live on all 4 consolidation profiles: 5–8s each, ~900 tokens, exact specialized skill compliance.
2. **Stale `model.base_url`/`key_env` in `_upsert_hermes_config_yaml` & stateful reviewer profiles:**
   - `_upsert_hermes_config_yaml` left stale `base_url:` / `key_env:` / `api_mode:` under `model:` when setting `provider: local-router`.
   - Consolidation reviewer profiles (`consolidate-goldfish`, `consolidate-archivist`, `consolidate-structural`) were not set `stateless=True` (`memory_enabled: false`).
3. **Lock race between `spawn_consolidate` and `spawn_autolearn` + permanent dead-PID lock wedges:**
   - `run_context_command` spawned `context-consolidate` and microseconds later spawned `context-learn` before the child created `.learn.lock`; both raced on `.learn.lock` and the loser exited silently (`DEVNULL`).
   - `acquire_lock` never checked PID liveness, so a crashed background pass wedged consolidation forever.
4. **Zero background observability:**
   - Detached `context-consolidate` wrote to `DEVNULL` with no last-run status file, hiding crashes, lock refusals, fallback transports, and panel failures.
5. **Unbounded `DIGEST-*.md` accumulation & chronological sort bug:**
   - Every run created a new `DIGEST-<folder>-NN.md` while keeping all old `DIGEST-*.md` files forever (`.agents/memories/` already has 5 digests, all indexed into the retrieval graph).
   - `folder_census` sorted by raw ASCII filename, putting legacy `2026-11-25-memory.txt` (`'m'`) ahead of `2026-11-25-22-memory.md` (`'2'`).
6. **Missing `--context-consolidate` wrapper in `bin/ainish-coder`.**

## 4. Implementation Checklist

- [x] `src/context/engine.py`: add `ignore_rules` & `preload_skill` to `hermes_profile_call`; update `consolidation_call` to pass `model=_consolidate_model()`, `ignore_rules=True`, `preload_skill=profile`, and explicit fallback metadata; clean stale `model.*` keys in `_upsert_hermes_config_yaml` and set `stateless=True` for consolidation reviewers in `run_context_setup`.
- [x] `src/context/engine.py`: fix chronological `_record_sort_key` in `folder_census`; support rolling digest compaction (flag `needs_consolidation` when `candidates` OR `digests > 1`; fold existing digests + candidates into one verified digest and remove superseded digests only after verification); record `agents`/`profiles_used`/`transports_used` in digest frontmatter and run output.
- [x] `src/context/engine.py`: prevent `spawn_consolidate` / `spawn_autolearn` lock race (defer `autolearn` when `consolidate` spawned); add stale dead-PID lock reclamation for consolidation; add `--background` flag to `context-consolidate` and persist `.agents/rag/consolidate-last-run.json` (surfaced in `spawn_consolidate` provenance).
- [x] `bin/ainish-coder`, `src/help.sh`, `llms.txt`: wire `--context-consolidate`, update help and DOX docs.
- [x] `src/context/tests/test_context_injection.py`: add unit tests covering Hermes `--ignore-rules` + `-s <profile>` + model flags, chronological sort (`-22-` vs `-memory.txt`), rolling digest compaction (including fail-closed preservation on failed review), `spawn_consolidate` / `spawn_autolearn` non-race, stale-PID lock reclamation, and `consolidate-last-run.json` provenance.
- [x] Verify: `py_compile`, `bash -n`, full `unittest` suite (compare against baseline), and a live end-to-end smoke on a scratch repo proving `--context` spawns the background Hermes consolidation panel and compacts folders to 3 newest originals + 1 verified digest.
- [x] Closeout: task record, COMMS ledger, daily memory, push to PR #19, confirm green CI and clean worktree.
