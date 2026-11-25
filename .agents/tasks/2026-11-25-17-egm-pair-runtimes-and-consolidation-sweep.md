# Task: EGM Pair Pinned Runtimes (Elephant = Hermes profile, Goldfish = Pi agent) and Every-Run Consolidation Sweep

- lane: now
- branch: `feat/egm-pair-runtimes-and-consolidation-sweep`
- worktree: `D:/Code/ainish-coder-worktrees/feat-egm-pair-runtimes-and-consolidation-sweep`
- status: done
- plan: `.agents/plans/2026-11-25-17-egm-pair-runtimes-and-consolidation-sweep.md`
- scope: `src/context/engine.py`, `src/context/tests/test_context_injection.py`, `src/help.sh`, `llms.txt`
- objective: Run the prime context pair on the operator's pinned runtimes — the elephant on a specified Hermes profile, the goldfish as a Pi agent — with the concatenated pair output on EVERY `ainish-coder --context` call (`skip_retrieval` governs the corpus only), and make the `consolidate-*` Hermes panel verify and condense every `.agents/` context folder on every call while maintaining the three newest files of each folder.

## What changed

1. **Pinned pair runtimes.** `_context_agent_call` dispatches from `CONTEXT_ROLE_TIERS`: elephant `hermes → pi → driver` on the specified profile (`AINISH_CONTEXT_ELEPHANT_PROFILE`, default `context-elephant`), goldfish `pi → driver` (the reviewer is not the drafter's transport either). Every tier after the first is a recorded `degrade_note`; `fallback_from` now names the tier that actually failed instead of a hardcoded hermes label. `AINISH_CONTEXT_RUNTIME` remains the explicit operator override.
2. **The pair runs on every call.** `skip_retrieval` skips the corpus retrieval ONLY; the prime is the concatenated elephant+goldfish output. The route-skip note moved from `degrade_notes` to `provenance.route_note` (rendered `<!-- route: ... -->`), so a deliberate skip no longer flags the envelope `degraded: true` — the operator's 2026-11-25 pasted symptom.
3. **Every-run consolidation sweep.** `spawn_consolidate` runs a synchronous verification census of all five coordination folders on every call (report `.agents/rag/consolidate-sweep.json`, which also names indexed-but-excluded folders — `federation` is the read-only CoD ledger and is never digested), then spawns ONE `context-consolidate` child covering ALL folders whenever any holds records beyond `CONSOLIDATION_PROTECTED_NEWEST` (3). `CONSOLIDATION_DEFAULT_CAP` = the retention (3); `AINISH_CONSOLIDATE_INTERVAL_S` default 24h → 0 (every run, still lock-guarded and kill-switchable via `AINISH_CONSOLIDATE_ON_CONTEXT`).

## Verification & Closeout Evidence (2026-11-25)

- `python3 -m unittest discover -s src/context/tests -p "test_*.py"`: **163 tests, 4 failures** — identical failure names to the pre-change baseline (**155 tests, 4 failures**: `RoleModelSeparationTest.test_the_two_roles_request_the_same_model_by_default`, `MasterSurfaceLensesTest.test_shared_rules_file_is_loaded_and_strip_ansi`, 2 × `WikiVaultPreservationTest`). Both non-wiki failures re-confirmed on pre-change `c8cb96a` (main checkout). Zero new failures; 8 new tests pass (4 × `RoleRuntimeTierTest`, 4 × `ConsolidationSweepTest`, including the data-loss regression "an unusable digest deletes nothing").
- Contract test `test_skip_retrieval_route_emits_no_filler_and_no_driver_spend` rewritten to `test_skip_retrieval_route_runs_the_pair_without_filler_retrieval` (the new contract: no filler retrieval, pair runs and concatenates, route note in provenance, `degraded: false`).
- Live smoke #1 (scratch repo, real `bin/ainish-coder --context "hello there" --json`, real local-router chain): sections `[orientation, elephant, goldfish]` in order on a `skip_retrieval` route, `provenance.route_note` = "retrieval skipped by route: …", sweep verified all five folders (tasks: 5 originals, protected = the 3 newest by record date, 2 candidates) and spawned `context-consolidate`. First-smoke `degraded: true` was HONEST transport degradation, every step recorded: elephant `hermes profile 'context-elephant' missing` → DriverEngine; three goldfish steps `pi returned no text blocks in 2 attempt(s)` → DriverEngine.
- Digest gate proven live: the background child produced no usable digest on the degraded chain and deleted NOTHING (originals intact) — `_digest_is_usable` holding the line.
- `bin/ainish-coder --context-setup` on `wsl-94gb`: 6/6 Hermes profiles created (`context-elephant`, `context-goldfish`, `consolidate-elephant`, `consolidate-goldfish`, `consolidate-archivist`, `consolidate-structural`) + `~/.pi/agent/models.json` loopback wiring, verified by read-back of every `config.yaml`.
- Live smoke #2 (post-provisioning, `--context "hello again" --json`): sections `[orientation, elephant, goldfish]` concatenated again on a skip route with the route note in provenance; the elephant now REACHES `context-elephant` (the degrade changed from "profile missing" to "hermes timed out after 300s") and goldfish pi steps returned empty blocks again — the pair was served by `DriverEngine`, every degrade recorded. The sweep spawned `context-consolidate` for `tasks` again (child still processing at closeout; originals intact — the `_digest_is_usable` gate deletes only after a usable digest is written and re-read). See `.agents/suggestions/2026-11-25-18-pair-transport-durability.md`.

## Deliberately not done

- local-router chain drift (repo canonical vs the 2026-11-23 exported live chain; the running router rewrites `fallback-models.json`) and the z.ai 401 health-probe spam: operator/local-router concerns, recorded in `.agents/suggestions/2026-11-25-18-local-router-chain-drift-and-health-401s.md`, not changed here.
- Goldfish `pi` empty-block durability (all three steps degraded in smoke #1): the pi pin is the operator's architecture, so widening the ladder is a policy call — `.agents/suggestions/2026-11-25-18-goldfish-pi-empty-blocks.md`.
- `AINISH_CONSOLIDATE_INTERVAL_S` kept as an operator throttle (default 0) rather than deleted.
