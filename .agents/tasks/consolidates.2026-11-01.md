---
format: ainish/context-digest/v1
schema: consolidates.{naming}.md
folder: tasks
period: 2026-11+
records_consolidated: 30
consolidated_at: 2026-11-27T00:39:50.969737+00:00
profiles: [consolidate-elephant, consolidate-structural, consolidate-archivist, consolidate-goldfish]
transports: [hermes]
sources:
  - DIGEST-tasks-2026-11.md
  - 2026-11-07-rag-context-injection-task.md
  - 2026-11-07-security-consolidation-task.md
  - 2026-11-08-agents-md-concision-task.md
  - 2026-11-08-plans-artifact-task.md
  - 2026-11-08-verify-system-wiring-task.md
  - 2026-11-11-federation-verify-task.md
  - 2026-11-11-handoff-notes.md
  - 2026-11-11-rag-obsidian-wiki-task.md
  - 2026-11-11-rules-sync-signing-task.md
  - 2026-11-11-skills-payload-split-task.md
  - 2026-11-20-14-context-consolidation.md
  - 2026-11-20-21-machine-sync-fleet-hardening.md
  - 2026-11-21-00-consolidation-specialist-agents.md
  - 2026-11-21-00-fleet-sync-reliability.md
  - 2026-11-21-05-context-prime-consolidation-jobs.md
  - 2026-11-21-09-consolidation-panel-sequence.md
  - 2026-11-21-14-airpc-lifecycle-demo.md
  - 2026-11-21-14-airpc-skill.md
  - 2026-11-21-15-airpc-distribute.md
  - 2026-11-21-15-consolidate-suggestions-2026-11.md
  - 2026-11-21-16-consolidate-comms-2026-11.md
  - 2026-11-21-18-consolidate-memories-2026-11.md
  - 2026-11-22-00-git-pr-protocol.md
  - 2026-11-22-13-fast-rules-tooling.md
  - 2026-11-22-14-federation-profile-cleanup.md
  - 2026-11-23-18-prompt-license-governance.md
  - 2026-11-24-21-context-hermes-and-machine-sync.md
  - 2026-11-25-13-agents-federation-cod.md
  - 2026-11-25-15-context-cli-wiring.md
---

# Digest — `.agents/tasks`, 2026-11+

This digest replaces 30 record(s) from 2026-11+. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Partial digests

The merge step did not pass review, so these 9 verified partial digests are kept as written. Each covers a different batch of the records named above.

Period 2026-11 covered two landed pieces of work on the ainish-rag context system: the context-injection pipeline and its contract surface (driver chain, Elephant/Goldfish synthesis, the <CONTEXT_INJECTION> section, 11 defects fixed; recorded done 2026-11-07), and the 2026-11-20 contract cleanup that dropped engine internals from the contract while keeping the output-treatment rules, plus a stale-path fix in src/context/engine.py.

Replaces DIGEST-tasks-2026-11.md, rolled in fully. Sources: R7 = 2026-11-07-rag-context-injection-task.md (branch feat/rag-context-injection, lane now, status done); R20 = 2026-11-20-11-contract-drop-internals.md. Both originals remain recoverable from git history; omissions here are deliberate.

## Accomplished
- R7: AGENTS.md now integrates the ainish-rag context-injection system — an agent reads the contract, makes one tool call, and receives an engineered injection combining Elephant (session-aware) and Goldfish (stateless) additions, with a real model chain and a genuine offline floor; a follow-up pinned the chain explicitly, carried by ainish-rag rather than local-router's shared fallback content.
- R7: driver chain verified live 2026-11-07, all four router steps answered DRIVER_OK: local-router/fallback-models -> mimo-v2.6-pro; zai-glm-5.3-flash -> glm-5.3-flash; xiaomi-mimo-mimo-v2.6-pro -> mimo-v2.6-pro; openrouter-deepseek-v4.1-flash-1017 -> deepseek/deepseek-v4.1-flash-1017; step 5 (direct deepseek call) only if the router is unreachable.
- R7: engine landed DriverEngine (tier order with env override, per-tier timeouts, source discipline, attempts log, never-raising chat()), driver_model_matches, reasoning-budget guard, elephant_synthesize/goldfish_review (Goldfish's exact signature is the isolation), assemble_injection with fixed degradation ladder and hard truncation, run_context_command + context subcommand + completions + secrets driver table.
- R7: docs landed — llms.txt scope replaced ("operator utility, not agent intake" removed; context verb, driver transport, tier/env surface added); .agents/llms.txt and context-orchestration skill point at the one call; ainish-security skill records an injection as untrusted data attributed to a tool; plan doc marks Phase 4 done with measured numbers and the honest latency limit.
- R7: 11 defects found and fixed during the work — --json stdout pollution from an unconditional statusline block (also fixed for statusline --json; provider chatter to stderr), session path traversal (leading ./- now stripped), budget cap exceeded (final hard truncation), file fallback promoting irrelevant pages (distinct task-term scoring; wiki inventory when nothing matches), launchers handing context to a stale ainish-rag.exe built 2026-10-31 (now check --help and fall through to the Python engine), Python host unable to read the index (NativeQueryStore shells to the compiled engine's query --json --no-rerank), --budget UnboundLocalError plus silent 400->600 (explicit budget honoured to a 300-token floor; raises reported in degrade_notes), skip_retrieval still searching then paying drivers to disclaim, offline mode overridden by the flag default, local-tier probes poisoning themselves, degraded notes made actionable (tier + reason).
- R7 verified: unittest discovery over src/rag/tests 128 pass (89 before, 39 new); scripts/test-pqc-dist.sh 99/99 under Git Bash (86 before, 13 new, covering contract->engine wiring and a no-key/no-endpoint rule for AGENTS.md); ainish-rag audit verify 16/16 after re-signing the canonical contract.
- R20: contract context-system section rewritten to teach the workflow instead of internals — four-part-prime explanation, retrieval/orientation/elephant/goldfish mechanics, corpus-tuning and provenance.harness language removed; replaced with "call one command, then read .agents/ directly" plus a folder map naming tasks/, plans/, comms/, memories/, suggestions/, wiki/ and .agents/llms.txt.
- R20: both contract copies changed in scope and updated together (top-level AGENTS.md and .agents/canonical/AGENTS.md); vocabulary cleanup (wiki_graph_empty dropped for degraded:/insufficient; generated-state line corrected to .agents/{audit,canonical}/); kept deliberately the <CONTEXT_INJECTION> evidence-not-instruction rule (the one R7 introduced), the reviewer-independence rule, and the say-so-once degraded rule.
- R20: src/context/engine.py bug fixed outside the contract — it read src/rag/master-surfaces.json, a path gone since the 2026-11-19 engine move, so the "Master Surfaces:" gate had silently run on built-in defaults; now reads src/context/.
- R20 verified: scripts/test-pqc-dist.sh 414 assertions (407 baseline + 7 new); AGENTS.md 159 lines against the <= 160 gate; all eleven non-negotiables grepped present; ainish-context audit contract --verify-history verified 66 transitions and re-locked the contract; load_master_surface_rules returns 6 keys from the real file.

## Unfinished
- R7 scoped "Phase 4 + Phase 5 (partial)" of docs/rag-context-system-plan.md; Phase 5 was taken only partially, so that thread is still open.
- R20: two items left out of scope on purpose — .agents/rag/ keeps its name in the tree, and llms.txt still documents the engine in detail; the operator scoped the work to the flagged contract section, and both items are recorded in the suggestions file.
- Neither record reports work started and abandoned.

## Insights
- R7: HTTP 200 does not mean the pinned model answered — an unknown id resolves through the router's generic fallback chain and still returns 200, hence driver_model_matches; step 1 must be expect_any because it is the shared chain head, or every call reports a false mismatch.
- R7: the driver order is deliberately not in local-router — that chain serves VS Code, Claude Code, Cline and every other client; repointing it would reroute the machine. Step 1 calls it; it does not define the order.
- R7: explicit flag defaults beat env config — DriverEngine(allow_remote=not no_remote) passed True and disabled AINISH_RAG_DRIVER_OFFLINE, so an "offline" run still reached a paid provider; likewise a 1.5 s probe timeout cached a negative and permanently disabled the offline floor for the process.
- R7: the contract and the code had to move together — the contract said the engine was "not an agent intake requirement" and the engine had no generative path, so the contract could not honestly point at the pipeline.
- R7: parsing the compiled engine's output is deceptively hard — ANSI SGR contains [ and the [rag:embed-provider] log tag looks like a JSON array start; the payload is now located by a line-anchored regex after stripping colour.
- R20: rule-loading failures degrade silently instead of erroring — the stale master-surfaces.json path meant the gate ran on defaults for an unknown period with no signal; the fix is invisible in tests until someone checks what the rules actually return.
- R20: the line gate is <=, not == — 159 of 160 is headroom, and padding a contract to an exact count is the failure mode the gate exists to prevent (the plan said 160; not padding was the deliberate deviation).
- R20: a contract section should hold rules about how to treat system output, not a description of how the system is built — the former survive rewrites, the latter rot.

## Recurring
- Silent degradation is the one pattern attested in both records: R20's stale-path rule-loading silence, and R7's silently applied budget (400->600), offline flag overridden by its default, skip_retrieval paying drivers to disclaim, and unactionable degrade notes; both records' fixes push toward observable failure (actionable notes, verification gates).
- The prior digest's watch item stands: the stale-path-after-move bug is attested only once (R20) but is the most likely specific recurrence; no other lesson appears more than once.

---

## Overview

Three completed tasks on `ainish-coder` in November 2026: consolidating four security skills into one `ainish-security` pack and replacing `context-orchestration` with a `rag context` orientation section, cutting `AGENTS.md` from 208 to 90 lines, and giving `question-me` a durable `.agents/plans/` artifact wired through deploy and orientation.

## Accomplished

- **One security skill landed** (2026-11-07-security-consolidation-task.md). `.agents/skills/ainish-security/` now contains `SKILL.md` (~270 lines, ten non-negotiables plus per-domain treatment) and four references (`code-and-infrastructure.md` ~560, `ai-and-agentic.md` ~640, `governance-and-cryptography.md` ~290, `deployable-standards.md` ~230). This replaces the old four-pack split — `code-security` (1,041 lines), `llm-security` (1,092), `production-security` (215), and the thin 88-line `ainish-security` that summarised the others — whose depth content now lives in the new references; the thin summary pack was rewritten in place under the same name. `code-security`, `llm-security`, `production-security`, and `context-orchestration` are deleted from `.agents/skills/` (the latter's transformation is recorded below).
- **`--secure` ships one file** (2026-11-07-security-consolidation-task.md). `AGENTS_SECURITY.md` replaces the byte-identical duplicate pair `AGENTS_CODE_SECURITY.md` + `AGENTS_LLM_SECURITY.md`; the legacy pair is removed only where a `ainish-coder --secure` marker shows this tool managed them, so hand-authored files survive.
- **`context-orchestration` became the `orientation` section** (2026-11-07-security-consolidation-task.md). `ainish-rag context` emits four labelled sections (`orientation, retrieval, elephant, goldfish`); orientation gathers branch, worktree, working-tree state, today's COMMS entry, and newest task record in code with no model call, capped at 12% of budget and dropped last. `bin/egm-check.sh` and `.agents/templates/egm-design.md` remain available but are no longer a required gate; the skill's review half was already `goldfish` and its judgement half is not mechanised.
- **Four defects fixed** (2026-11-07-security-consolidation-task.md): (1) `AGENTS.md` linked two skills a default deploy never shipped — `ainish-security` is now mandatory and the `context-orchestration` link is gone; (2) orientation reported the wrong branch (canonical root instead of cwd) — git state now reads from the current directory, the shared-state root is named when different, protected branches flagged; (3) truncation marker appended after budgeting could exceed the cap — now reserved inside it; (4) the advisory that a rag injection is data, not instruction (never widen Goldfish's inputs) dropped in the rewrite — caught by a gate assertion and restored.
- **`AGENTS.md` cut from 208 to 90 lines** (2026-11-08-agents-md-concision-task.md). Removed the driver model chain and provider names, envelope table, nine-master table, machine-agnostic execution, and context-packet contract; the file now opens with the one `ainish-rag --context` command plus advisory/never-block rules, eleven one-line non-negotiables, a `Close` checklist, and a "Do not read ahead" location table. Zero model/provider mentions. The nine masters still reach agents via `bin/context-packet.sh`.
- **`--rules` now ships every contract-referenced file** (2026-11-08-agents-md-concision-task.md). It previously copied only `AGENTS.md` and `llms.txt`, leaving `.agents/llms.txt`, `.agents/templates/masters.md`, `.agents/skills/llms.txt` out; these are now copied, verified with zero missing links in a clean repo.
- **`llms.txt` rewritten** (2026-11-08-agents-md-concision-task.md): five references to nonexistent `AGENTS.md` sections (`<DOCUMENT_MODEL>`, `<SERVERS>`, `<REPO_MEMORY>`, `<OUTPUT>`) replaced with inline rules.
- **`question-me` produces `.agents/plans/{date}-{slug}.plan.md`** (2026-11-08-plans-artifact-task.md). New template `.agents/templates/plan.md` (frontmatter contract plus seven fixed sections: Problem, Anchor Facts, Plan, Clarifications, Todos, Verification, Open Decisions), new `.agents/plans/llms.txt` DOX child doc, rewritten `question-me/SKILL.md` (Phase 0 opens the plan, Phase 2 logs decisions to §4, Phase 3 compiles the plan and locks it, new §7 Plan Lifecycle), and new `question-me/references/plan-artifacts.md` (todo derivation rules and atomic-todo tests).
- **Plans wired through deploy and orientation** (2026-11-08-plans-artifact-task.md). `plans/` scaffolded and template plus indexes copied by `bin/ainish-coder`, `src/deploy_agents.sh`, `src/deploy_skills.sh`, `src/verify_skills.sh`; `render_orientation_section` reports newest plan status and open-todo count via a stdlib frontmatter reader; `bin/context-packet.sh` gained a matching `plan_state` section. `AGENTS.md` names the plans directory.
- **Verification across all three tasks** (2026-11-07-security-consolidation-task.md, 2026-11-08-agents-md-concision-task.md, 2026-11-08-plans-artifact-task.md): `py -m unittest discover -s src/rag/tests` at 143, then 164, then 172 pass; `scripts/test-pqc-dist.sh` at 131/131, then 156/156, then 150 new-plus-existing assertions; `ainish-rag audit verify` 16/16 after re-signing each time; clean-repo deploys verified end to end (both mandatory packs deployed with every link resolving; `--secure` producing exactly one file; plans target receiving `.agents/plans/`, the template, and the index).

## Unfinished

- **Rust engine parity for `context`** (2026-11-07-security-consolidation-task.md). `src/rag/src/main.rs` does not implement `context` at all, so the launcher falls through to Python on hosts using the compiled binary. Pre-existing and unchanged by the security work.
- **`--secure` signing path untested with the compiled signer** (2026-11-07-security-consolidation-task.md). The worktree had no `bin/ainish-rag.exe`, so the `--rules` run refused at the signer preflight while still deploying content; only the content path is verified.
- **`orchestrate-subagent-masters` deletion left to the operator** (2026-11-07-security-consolidation-task.md). It showed as deleted before the task began; the retired-pack lists still name it so target copies are cleaned on their next deploy.
- **No `plan-check.sh` gate** (2026-11-08-plans-artifact-task.md). Deliberately deferred until real plans exist and failure modes are known rather than guessed.
- **No migration of historical `.agents/tasks/` records into plans** (2026-11-08-plans-artifact-task.md). They were written under the old contract; rewriting them would fabricate decisions nobody made.
- **No `--question-me` CLI verb** (2026-11-08-plans-artifact-task.md). Deliberately not added — the skill is agent-invoked.
- **`--rules-verify` reports `NO_VERIFIER` for six sibling targets** (2026-11-08-plans-artifact-task.md). Identical on the `663da33` baseline: those manifests are stale and this WSL host has no signer.
- **Baseline worktree `D:\Code\ac-plans-baseline` cleanup** (2026-11-08-plans-artifact-task.md). Detached scratch checkout; can be removed with `git worktree remove D:/Code/ac-plans-baseline --force`.

## Insights

- `SKILL.md` is designed as an **instructional**, not a table of contents (2026-11-07-security-consolidation-task.md): state the domain-independent rules and enough of each field to act on, then point at references for depth. The old split's only cross-domain file was the thin 88-line `ainish-security` summary that omitted nearly everything actionable — the practical outcome was that the summary got loaded and the depth did not.
- Cross-referencing packs by relative path (`code-security` → `../../llm-security/references/...`) forced an agent to know in advance whether a task was "code" or "AI" before it could be correct (2026-11-07-security-consolidation-task.md).
- Byte-identical duplicates are how a deploy ships stale content without anyone noticing (2026-11-07-security-consolidation-task.md): the old `--secure` pair were unmodified copies of `production-standards.md` files, verified by digest.
- Documentation describing a routine the tool already implements (`context-orchestration` vs `ainish-rag context`) makes agents do by hand what should be gathered mechanically — branch, worktree, tree state, COMMS are tool work (2026-11-07-security-consolidation-task.md).
- A short document makes its pointers load-bearing (2026-11-08-agents-md-concision-task.md): compression concentrates claims, decorative links become load-bearing, and never-true facts surface immediately — the missing-file finding only appeared after the cut.
- The test for whether a line belongs in `AGENTS.md` is not "is it true" but "does reading it change what the agent does next" (2026-11-08-agents-md-concision-task.md).
- A file that grows back into a manual does so one reasonable-sounding section at a time, so length is worth asserting (2026-11-08-agents-md-concision-task.md): 13 gate assertions pinned strings including the model chain; each was re-decided rather than mechanically repointed, with new assertions enforcing absence of model names plus a line ceiling.
- Coordination state (branch, status, scope, verdict) and working intent (plan, clarifications, todos) are different artifacts with different lifetimes — the second is read repeatedly during implementation and belongs in its own directory (2026-11-08-plans-artifact-task.md).
- A linter is only worth writing once real plans exist and failure modes are known rather than guessed (2026-11-08-plans-artifact-task.md).

## Recurring

- **Dangling links in default deploys** (2026-11-07-security-consolidation-task.md; 2026-11-08-agents-md-concision-task.md). Twice: `AGENTS.md` linked skills a default `--rules` run never shipped, and the shortened contract pointed at `.agents` files `--rules` never copied. Both fixed by making deployment ship everything the contract references; the concision task added a `test-pqc-dist.sh` assertion that `--rules` names every contract-linked `.agents` file.
- **Pre-existing WSL-host test failures confirmed against a detached baseline** (2026-11-08-plans-artifact-task.md; implied in 2026-11-08-agents-md-concision-task.md's clean runs). 14 `pqc-install`/`pqc-status` failures and `NO_VERIFIER` manifests reproduce identically at `663da33`, i.e. environment, not regression.
- **Contract re-signing after every contract touch** (all three sources): `ainish-rag audit verify` 16/16 after re-signing each time, with contract history chained to the new digest (`84be207a…` for the plans task).
- **Assertions pinned to removed content had to be re-decided, not repointed** (2026-11-07-security-consolidation-task.md defect 4; 2026-11-08-agents-md-concision-task.md note on gate assertions): both rewrites risked silently dropping a rule (the rag-injection advisory; the model-chain assertions), and both were caught by gate assertions during the rewrite.

---

## Overview

This period covered an end-to-end verification of the RAG system wiring (correct but retrieval-blind on a missing embedding credential), the federation/peer-sync tooling (peer forecasting, smoke probes, checkout dedupe), and a handoff consolidating the local-router chain, graph-only retrieval, and Windows launcher fixes across three machines.

## Accomplished

- System wiring verified end to end: the decision model (`route`, 0.9–1.6 s), the documented `--context` interaction (exit 0, all four sections, full provenance), and the never-block rule (retrieval unavailable still exits 0 with `degraded: true`) all work; only vector search failed, on a 401, not a defect (`2026-11-08-verify-system-wiring-task.md`).
- Defect fixed: `NativeQueryStore.search_with_reason(query, limit)` now returns a reason on every early return (no binary, non-zero exit carrying engine stderr, no output, no JSON array, no hits), so a 401 no longer reports as `native_engine_empty (no_store)`; `search` keeps its list shape. 167 rag tests pass (3 new) and 158/158 `scripts/test-pqc-dist.sh` assertions (`2026-11-08-verify-system-wiring-task.md`).
- Federation landed (`2026-11-11-federation-verify-task.md`): `_ms_peer_forecast` (per-peer commits ahead/behind, fast-forward verdict with exact blocking paths), `_ms_smoke_peer` (bounded read-only post-sync probe, reports "unverified" without failing the sync), `_ms_checkout_id` (normalizes `/mnt/<d>/...` and `<D>:/...` to one identity so a shared tree syncs once). 217/217 dist tests incl. nine new federation assertions; live dry run prints `0 ahead / 0 behind` and the same-checkout notice.
- POSIX-shell gate landed and proven (failed on a deliberately reintroduced `cd &&` remote command, then restored); a Windows-safe probe path landed (`.cmd` wrapper for drive-letter roots, plan-check status from ssh's exit code) (`2026-11-11-federation-verify-task.md`).
- Peer advanced from `e2f5cc7` to `7f4f725` (12 commits) with a clean tree (`2026-11-11-federation-verify-task.md`).
- All three machines on the same commit and router chain (`fallback-models.json` hash `e0792421`), installed live on the Mac and Windows, staged on WSL (`2026-11-11-handoff-notes.md`).
- Retrieval is graph-only and verified working: `--context` walks a wiki graph + newest `.agents` artifacts, no embedding server or API spend; ~3.8 s, `mode wiki_graph`, `sufficiency sufficient`, `degraded: false`. `AINISH_RAG_VECTOR_FALLBACK=1` is the only way back (`2026-11-11-handoff-notes.md`).
- `--machine-sync --auto-commit` proven end to end: edit on WSL → commit `7609e64` → present on the Mac; peers fast-forward by default, `--no-ff-peers` opts out (`2026-11-11-handoff-notes.md`).
- `scripts/local-router-sync.sh` landed as the installer (`--verify`, `--capture`, `--dry-run`): derives the declarative `routes.boot.json` from the persisted chain, omits invalid routes from it, and mirrors the chain into `router-settings.json`; refuses an empty chain in both directions (`2026-11-11-handoff-notes.md`).
- Launcher fixes landed: the binary is `ainish-rag.native.exe` called only by the `.cmd`; both the `.cmd` and the extensionless POSIX wrapper are patched; `uv run --no-managed-python` is required on Windows only (`2026-11-11-handoff-notes.md`).
- WSL is a working initiating machine: `machines.txt` (`wsl-94gb=self`, `mac-18gb=mac-18gb:/Users/nbiish/code`), ssh alias to the Mac at `192.168.1.68`, and the redundant `windows-128gb` peer line removed (`2026-11-11-handoff-notes.md`).

## Unfinished

- No embedding key restored (`LOCALROUTER_OPENROUTER_API_KEY` or `OPENROUTER_API_KEY` via `pqc-secrets`, or repin a provider): an operator credential decision. Until a key exists there is no live retrieval verification — hybrid search, decision reranking on real hits, and CRAG corrective expansion are verified only by unit tests (`2026-11-08-verify-system-wiring-task.md`).
- Flagged incident, unattributed: the PQC store was rewritten ~20 times between 19:55–20:05 UTC and now holds one key (`LOCALROUTER_TEST_VENDOR_API_KEY`) where it previously resolved 24; repo test suites are correctly sandboxed, so not them; coincided with the other tool's `wtf` work (`2026-11-08-verify-system-wiring-task.md`).
- Flagged incident, recorded: a cleanup removed historical `.agents/comms`, `.agents/tasks`, `.agents/suggestions` files; 167 tests and 158 gate assertions still pass, so nothing depended on them (`2026-11-08-verify-system-wiring-task.md`).
- `--status` still reports the Windows entry's stale `main` while the real HEAD has advanced, because both registry names read as independent peers; the checkout dedupe covers the sync path only (`2026-11-11-federation-verify-task.md`).
- No per-architecture build verification (`cargo check` on each peer) — the smoke probe proves the tool runs, not that a native build succeeds (`2026-11-11-federation-verify-task.md`).
- Anchor-rotation work from `fix/rules-sync-signing` (`ca10cd9`) remains parked and unmerged (`2026-11-11-federation-verify-task.md`).
- `--auto-commit` creates divergent lanes: WSL and the Mac both committed on top of the same parent and the sync still reported `✓ synced` for both while `main` was diverged (merged by hand as `fe93474`). Fix site `_ms_pull` — merge the peer's branch when it is not an ancestor of `HEAD` and the tree is clean, `git merge --abort` on conflict. Written up in `.agents/suggestions/2026-11-11-federation-gaps.md` (item 6) (`2026-11-11-handoff-notes.md`).
- local-router has no live reload; a saved config needs a restart. Plan: `.agents/plans/2026-11-11-router-live-reload.plan.md` (`2026-11-11-handoff-notes.md`).
- Scrolls belong outside `.agents/`. Plan: `.agents/plans/2026-11-11-scrolls-out-of-agents.plan.md`. Another agent is mid-move (working tree carries deletions of `.agents/skills/**`, incl. `8thfire-scrolls`, with `skills-to-distribute/skills/` appearing) — do not commit that move from this lane (`2026-11-11-handoff-notes.md`).
- `test-config.txt` not found anywhere checked (Windows `/d/Code`, `%USERPROFILE%`, router config dir, `/d/Code/local-router`; WSL `/mnt/d/Code`; Mac). The pasted textarea excerpt was placeholder text. The live Windows chain was dumped instead and matches the repo chain, so the saved config is already canonical; if the file exists elsewhere, point at it and `--capture` will take it (`2026-11-11-handoff-notes.md`).
- Windows warns its vector index was built with API embeddings — harmless under graph-first retrieval; `ainish-rag index --rebuild` clears it (`2026-11-11-handoff-notes.md`).

## Insights

- Falling back to local EmbeddingGemma would be worse than failing: the store was built with `text-embedding-3-small`, local Gemma vectors are a different space, and mixed-space retrieval returns confidently wrong neighbours instead of an error. The engine correctly refuses; do not switch providers without reindexing (`2026-11-08-verify-system-wiring-task.md`).
- A 401 and an empty store need completely different fixes (restore a credential vs. rebuild an index), so surfacing the engine's own failure reason is operationally essential (`2026-11-08-verify-system-wiring-task.md`).
- Transport working does not mean the peer is usable: refs reached the peer while its `main` sat at `e2f5cc7` behind `7f4f725` for days; only comparing the peer's `git rev-parse --short HEAD` to the received ref revealed it (`2026-11-11-federation-verify-task.md`).
- One half-staged stray file (`fallback-models.json.bak.*`, `AD`) blocked the whole fleet; clearing it let both peers fast-forward immediately (`2026-11-11-federation-verify-task.md`).
- The Windows peers' login shell is PowerShell: `&&`, `>/dev/null`, `2>/dev/null` are syntax errors there and remote commands using them fail silently. Already documented in snapshot plumbing (`_ms_snap_cmd` uses `git -C`) and easy to reintroduce (`2026-11-11-federation-verify-task.md`).
- `bin/ainish-coder` is a bash script, so probing it on Windows reports a healthy peer as unverified (`2026-11-11-federation-verify-task.md`).
- An unverifiable peer must read as "unverified", not as broken delivery — `_ms_smoke_peer` never fails the sync (`2026-11-11-federation-verify-task.md`).
- `local-router --config` (or `LOCAL_ROUTER_ROUTES_CONFIG`) takes the declarative shape `{"fallbackModels": {"<route>": {"models": [...]}}}`; the persisted file is `{"version":1,"routes":[...]}`. Handing it the persisted shape is silently ignored and the router then rewrites the persisted file from its own empty state — the installer "succeeds" while `fallback-models` serves `[]` (`2026-11-11-handoff-notes.md`).
- A checkout install of local-router reads `router-settings.json` from its own repository root and takes the chain from the `fallbackModelsText` string (one model id per line, the config page's textarea format); `~/.config/local-router/fallback-models.json` is only a mirror the router rewrites from its own state — writing only the mirror changes nothing (`2026-11-11-handoff-notes.md`).
- The router rejects the entire boot config if any route has fewer than two unique models (`Fallback route requires at least two unique model entries`); `fallback-decision` had one, so any boot config containing it failed and the installer fell back to `ensure`, dropping `--config` (`2026-11-11-handoff-notes.md`).
- `ainish-rag.exe` beat `ainish-rag.cmd` in PATHEXT order, bypassing `PY_ONLY_SUBCOMMANDS`, so `context` reached a binary that exits 2; Git Bash resolves `ainish-rag` to the extensionless POSIX wrapper, not the `.cmd` — both paths need patching (`2026-11-11-handoff-notes.md`).
- uv's managed interpreter under `%APPDATA%\uv` dies on this host with `untrusted mount point (os error 448)`; pass `uv run --no-managed-python` on Windows only — macOS needs the managed download for the pinned Python (`2026-11-11-handoff-notes.md`).
- The handoff records the canonical chain as 15 models (list: cline-deepseek-deepseek-v4-flash-free, xiaomi-mimo-mimo-v2.6-pro, zai-glm-5.3-flash, antigravity-gemini-3.7-flash, cursor-deepseek-v41-flash-1017, cursor-grok-4.7, cursor-auto, github-copilot-auto, kilo-deepseek-deepseek-v4.1-flash-1017-paid, opencode-zen-glm-5.3-flash, commandcode-deepseek-v4.1-flash, pioneer-deepseek-v4-pro, cline-deepseek-deepseek-chat-paid, openrouter-deepseek-v4.1-flash-batch, zenmux-deepseek-v4.1-flash) yet elsewhere calls the repo chain "17-model"; both statements are preserved as written in `2026-11-11-handoff-notes.md`. `test-config.txt` at `D:\Code\local-router\test-config.txt` would adopt a list via `--from-text=`.
- Verified test baselines at handoff: `bash scripts/test-machine-sync.sh` 26 assertions, `uv run python -m unittest discover -s src/rag/tests` 179 tests; after a sync, check `git merge-base --is-ancestor <peer>/main HEAD` (`2026-11-11-handoff-notes.md`).

## Recurring

- The same NTFS checkout registered as two machines: `2026-11-11-federation-verify-task.md` found `windows-128gb` and `wsl-94gb` are one tree (`D:/Code/ainish-coder` = `/mnt/d/Code/ainish-coder`) and synced twice per transfer; `2026-11-11-handoff-notes.md` separately removed WSL's `windows-128gb` peer line because it "was the same files and always failed".
- POSIX shell syntax in remote commands against Windows peers: `2026-11-11-federation-verify-task.md` records it as already documented in the snapshot plumbing and then reintroduced during this very work — a gate now exists because documentation alone did not prevent it.
- Vector index/provider-space mismatch surfacing in more than one place: `2026-11-08-verify-system-wiring-task.md` (store built with `text-embedding-3-small`; mixed space gives confidently wrong neighbours) and `2026-11-11-handoff-notes.md` (Windows warns its index was built with API embeddings).
- The router chain silently going empty: `2026-11-11-handoff-notes.md` marks the declarative-vs-persisted shape trap as a root cause learned "the hard way" that "kept going empty" across attempts, and separately notes the boot-config rejection route to the same empty state.
- Windows entry-point resolution defeating a fix applied to only one path: `ainish-rag.exe` (PATHEXT) and the extensionless wrapper (Git Bash) each bypassed the `.cmd`, requiring both to be patched (`2026-11-11-handoff-notes.md`).

---

## Overview

Three tasks landed on 2026-11-11: converting the generated wiki into a real Obsidian vault with a parseable link graph and an enforced plan gate; making the rules deploy fail honestly by verifying only what it wrote and naming the unfixable signer/anchor mismatch; and moving the distributable skill payload out of the agent context path into `skills-to-distribute/`.

## Accomplished

- Obsidian-native vault format: every page carries frontmatter (`title`, `aliases`, `tags`, `up`, `generated`, `source_commit`, `decision_source`), `[[page|label]]` wikilinks, and a `## Related` block; `.obsidian/` written once and never overwritten (2026-11-11-rag-obsidian-wiki-task.md).
- Graph reader taught wikilinks first: `WIKILINK_RE` + `MDLINK_RE`, stem matching for wiki targets, `GRAPH_NAV_HEADINGS` skipping navigation-only sections, `_strip_code_spans`; both old `(path.md)` and new `[[...]]` syntaxes parsed. Verified the old regex returned `[]` where the new extractor finds the target (2026-11-11-rag-obsidian-wiki-task.md).
- Plan gate: `--plan-check [DIR] [--json]` matches plan to branch via the plan's `branch:` key and refuses absent/`designing` plans; `--plan-gate-install` wires the pre-commit hook; `--plan-gate` is the hook-only entry. Proven end-to-end on real `git commit` (refused, bypassed-with-notice, allowed) (2026-11-11-rag-obsidian-wiki-task.md).
- Verification for the above: `cargo test` 58/58 including `generated_vault_is_obsidian_native` (frontmatter, wikilinks, no dangling targets, ledger byte-identical, vault config unclobbered); `scripts/test-pqc-dist.sh` 184/184 with six plan-gate assertions; live generation 32 nodes / 236 edges / 0 dangling / 0 phantom `Related` nodes; `ledger.md` byte-identical and `ledger.sig` stable across regeneration (2026-11-11-rag-obsidian-wiki-task.md).
- `audit verify --path <file>` verifies exactly one file (a missing envelope fails by name; a directory keeps its aggregate sweep) — the `NotADirectory` fall-through is gone (2026-11-11-rules-sync-signing-task.md).
- Deploy gate now verifies only the manifest it just wrote, not the whole `.agents/` directory (2026-11-11-rules-sync-signing-task.md).
- `ainish-rag audit anchor-check` prints `signer|anchor`, exits 3 on mismatch, silent/0 on agreement; `--rules` calls it and prints both fingerprints before deciding. Read-only: never writes the anchor, never re-signs, never clears flags (2026-11-11-rules-sync-signing-task.md).
- Rules-sync verification: 58 cargo tests pass; 229 assertions (8 new pinning the three fixes and refusing anchor rotation in the deploy path); `anchor-check` on the host reports `69e7233dc777…|d98405ea3684…`, exit 3; `--rules <tmp>` deploys, prints fingerprints, then refuses at manifest verification — the deliberate, not-gate-4 behavior (2026-11-11-rules-sync-signing-task.md).
- Test cleanup trap fixed: it now clears `uchg`/`+i` and write bits before removal (a deployed `AGENTS.md` is `uchg`-locked by design); 0 orphaned `pqc-dist-test.*` trees remain after a full run, down from 13 (2026-11-11-rules-sync-signing-task.md).
- Skill payload split: `src/paths.sh` defines `AINISH_SKILLS_SOURCE_REL` (`skills-to-distribute/skills`) and `AINISH_SKILLS_TARGET_REL` (`.agents/skills`) once; all ~30 hardcoded source sites across nine scripts now call the resolvers (2026-11-11-skills-payload-split-task.md).
- `.agents/skills/` reduced to four packs this repo's agents read (`ainish-security`, `pqc-secrets`, `question-me`, `security-first-agent`); contract links resolve at deployed paths. `pqc_dist.sh` splits `_PQC_PACK_REL_SOURCE`/`_PQC_PACK_REL_TARGET` with a legacy fallback for old launchers; `decision.rs` probes both layouts for the pqc engine (2026-11-11-skills-payload-split-task.md).
- Skills-split verification: `test-pqc-dist.sh` 183/183 (from 167 pass / 17 fail); end-to-end `--rules --headless` deploys 19 packs + `skills/llms.txt` + `AGENTS.md` + `llms.txt`, second run idempotent, `--skills-verify` `identical=19 mismatch=0`, `--skills-list` enumerates 20 deployable packs; `cargo test` 57/57; `diff -r` proves the payload byte-identical to what `HEAD` held at `.agents/skills/` and the four local packs byte-identical to their payload counterparts (2026-11-11-skills-payload-split-task.md).
- Three gate bugs fixed during that verification: `jget` switched to `sed -E` (BSD sed ignores `\|` in basic regex, so every boolean/scalar assertion silently read empty on macOS); `skills_selection.sh` now sources `paths.sh` first; one assertion relaxed from a single phrasing of the degradation rule to the behavior (2026-11-11-skills-payload-split-task.md).
- `bin/ainish-rag-darwin` (127 MB local build product) is gitignored (2026-11-11-rag-obsidian-wiki-task.md).

## Unfinished

- Decision-driven salience (plan items 5.4/5.5) is designed but not wired. Every page reports `decision_source: structural`; wiring it now would emit a fallback pretending to be a decision, which the repo forbids. Blocked on provider authorization: both decisions-capable models (`openrouter/jev-1.14`, `zenmux/jev-1.14`) reject — 401 "User not found" and 403 payg respectively. Chat failover does work (2026-11-11-rag-obsidian-wiki-task.md).
- Python parity (plan item 5.7): `rag.py` has the reader half of wikilink parsing only; the Python generator still emits the old page format — the writer half remains (2026-11-11-rag-obsidian-wiki-task.md).
- Trust-anchor rotation (plan todo 5.6): rotate the anchor and re-sign 18 tracked artifacts (14 in `.agents/audit/`, 2 in `.agents/canonical/`, `.agents/wiki/ledger.sig`, the `.scrolls**` set) in one pass, then set a durable `AINISHRAG_MLDSA65_SEED` in the vault. Deliberately a separate task (operator decision: "Rotation is deferred to its own task; it must not ride along with bug fixes"). Until then `--rules` prints both fingerprints and refuses at manifest verification — plan gate 4 does not and should not pass on a host whose signer is not the anchor (2026-11-11-rules-sync-signing-task.md).
- Consumer repos enrolled before the skills split keep working via the legacy engine fallback, but their `.agents/skills/` still holds every previously selected pack. Their selection, unchanged by design (2026-11-11-skills-payload-split-task.md).
- `AGENTS.md` intentionally untouched in the skills split: its three `.agents/skills/...` links are correct in consumer repos where the packs land; `.agents/llms.txt` carries the local map instead (2026-11-11-skills-payload-split-task.md).

## Insights

- Converting pages to `[[wikilinks]]` without teaching the graph parser would have deleted every explicit edge and left retrieval on the weaker `shared terms >= 3` rule — the vault would look better in Obsidian while `--context` silently returned worse results. The parser fix had to land first (2026-11-11-rag-obsidian-wiki-task.md).
- Every `## ` heading becomes a graph node, so a `## Related` cross-link section would compete with the content it links to; navigation headings need explicit skipping (2026-11-11-rag-obsidian-wiki-task.md).
- `ledger.sig` churned on every wiki run with the same content `sha256` but a new `signed_at` and, on this host, a different `public_key_fingerprint` — pre-existing, exposed while checking the ledger was untouched (2026-11-11-rag-obsidian-wiki-task.md).
- The signing key is not the committed trust anchor: `resolve_or_create_seed` invents a random seed and writes a gitignored `.agents/audit/signer.mldsa65.priv` when neither `AINISHRAG_MLDSA65_SEED` nor a vault seed exists. The original seed is unrecoverable — `pqc-secrets list` holds no seed, the only local private file is the invented one, and the anchor `.pub` is unchanged since `20da58c` (2026-10-12) — so the mismatch cannot be repaired by configuration (2026-11-11-rules-sync-signing-task.md).
- Rotation artifacts are not interchangeable: `.agents/canonical/AGENTS.sig` is signed by the local key `69e7…` while `.agents/wiki/ledger.sig` and the audit receipts are signed by the anchor key `d984…`, so a rotation must redo both groups in one pass or it invalidates one while fixing the other (2026-11-11-rules-sync-signing-task.md).
- A deploy is answerable only for what it wrote: judging the whole `.agents/` directory let six unrelated receipts (mcp-settings, a skill lock, contract history — and `ainish-deploy.json` itself among the failures) decide a rules deploy (2026-11-11-rules-sync-signing-task.md).
- Putting all 22 skill packs in `.agents/skills/` — the exact path harnesses auto-discover (`**/.agents/skills`) — made every session pay the full corpus as context regardless of task. Distribution and consumption sharing one path was the root cause of the reported context rot (2026-11-11-skills-payload-split-task.md).
- One resolver constant (`_PQC_ENGINE_REL`) served both this checkout's engine and a consumer repo's vendored engine; after the payload move these are different paths, and target-side checks would have silently inspected a directory that only exists downstream (2026-11-11-skills-payload-split-task.md).
- `ainish-rag-darwin` being 127 MB means build products of this tool can land in-tree unnoticed until git status or size checks surface them (2026-11-11-rag-obsidian-wiki-task.md).

## Recurring

- Host-specific tooling quirks silently corrupting tests on macOS: `jget`'s basic-regex `\|` read every assertion as empty on BSD sed (2026-11-11-skills-payload-split-task.md), and the `uchg`-locked `AGENTS.md` broke the `rm -rf` cleanup trap every run (2026-11-11-rules-sync-signing-task.md). In both cases the suite or tooling was wrong, not the code under test.
- "Refuse rather than report integrity you don't have" recorded twice: the wiki task declines to wire decision salience before providers authorize because a structural fallback posing as a decision is the forbidden silent-downgrade mode (2026-11-11-rag-obsidian-wiki-task.md); the rules-sync deploy refuses rather than accept a signature that isn't the anchor's (2026-11-11-rules-sync-signing-task.md).
- Local/committed trust state diverging on this host, recorded twice: `ledger.sig` carries a per-host `public_key_fingerprint` (2026-11-11-rag-obsidian-wiki-task.md) and the signer seed is machine-invented rather than the committed anchor (2026-11-11-rules-sync-signing-task.md). Both are the same underlying hazard: artifacts silently bound to a machine-local key.

---

Accomplished — what actually landed:

- `ainish-context context-consolidate` built and merged on `feat/context-consolidation` (status done; 426 assertions pass, 418 baseline + 8 new in `scripts/test-pqc-dist.sh`). It censes each folder (excluding `llms.txt` and `*.live.*`), protects the 3 newest records by filename date, chunks 5 at a time through the elephant, has goldfish review the draft, writes `DIGEST-<folder>-<period>.md` with a `sources:` frontmatter list, re-reads it, and only then removes summarised records (`2026-11-20-14-context-consolidation.md`).
- The data-loss guard `_digest_is_usable` landed with it: 200+ characters, ≥3 of 4 expected sections, and rejection of promise-openers ("I'll start", "let me first", "sure,"), with removal scoped to records a usable chunk covered. The 16 files deleted by the first bad run were fully restored from git (`2026-11-20-14-context-consolidation.md`).
- A real run on `.agents/suggestions` verified the tool end to end: 19 files → 3 originals + 1 digest, hand-inspected as specific, cited, accurate; folder then restored to 19 files, digest kept only as a sample (`2026-11-20-14-context-consolidation.md`).
- `AGENTS.md` re-signed at 160 lines, chain verified at 66 transitions, re-locked (`2026-11-20-14-context-consolidation.md`).
- Machine-sync's per-process bundle-name race fix (the corrected D1 root cause: a fixed peer-side filename `ainish-machine-sync-in.bundle` unlinked by a finishing cycle while another fetches) is committed on Mac `main` as `f16b286`, verified by deterministic reproduction plus `scripts/test-machine-sync.sh` (60 passed, 0 failed) and three concurrent `--both --ff-peers` runs with zero collisions. The Mac watcher was restarted onto the fix and logged one clean cycle (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- Federation itself verified converging (both machines at `ed875f1` after manual sync); TCC fallback for external volumes works (loopback ssh resolves to `ssh` as designed); Windows/WSL alias dedup onto one checkout identity works (`_ms_checkout_id`) (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- hermes v0.23.3 verified usable for non-interactive automation: `hermes -z "<prompt>"` one-shot works, `hermes -z ... --profile marketing-engineer` returns `SEZ_READY`, `hermes cron status` shows a live ticker (31s heartbeat, 2 active jobs), and `hermes cron create` accepts schedules plus `--deliver bot-chat[:profile]`. Two healthy cron jobs exist (hourly `Hermes Federated Backup`, daily `Hermes Federation Adopt` at 05:05) (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- A live machine-sync test delivered the ref to the peer (`refs/remotes/mac-18gb/main` = `c71f164`), correctly left the peer's divergent `main` untouched, and the watcher auto-committed as `Nanoboozhoo - embodied by cursor`, not the operator (`2026-11-21-00-consolidation-specialist-agents.md`).
- The `ainish-coder` self-link was removed 2026-11-21, quarantining the repo from the watch set (`2026-11-21-00-fleet-sync-reliability.md`).
- The restart test (2026-11-21 00:37) confirmed the `local-router` failure is a real delegated-cycle fault, not stale daemon state: a fresh launchd process with the bundle-name fix still failed attempt 57; also confirmed only one watcher runs under launchd (pid 53897) — a second `machine-watch --foreground` seen mid-cycle is a delegated child, not a duplicate (`2026-11-21-00-fleet-sync-reliability.md`).

Unfinished — started or required, not done:

- The other four context folders are untouched (~150K tokens still raw). Consolidating them replaces files and must run with the operator watching, one folder at a time (`2026-11-20-14-context-consolidation.md`).
- Machine-sync fleet hardening is "ready": plan written, tasks T1–T8 not implemented beyond the T1 bundle-race fix. Still open per the defect table: D2 watcher failed 11 of 37 cycles, D3 smoke probe always `unverified` on Windows (probes the wrong launcher path), D4 untracked-but-ignored files (`?? products/`) block fast-forwards, D5 ignored binaries have no transport (`_ms_wip_snapshot` uses `git add -A`), D6 `--auto-commit` uses the wrong git identity, D7 stale `watch.state` pid, D8 the tool's own repo not federated (mac `2ed96d2` vs win `1bd8865`, one `links.txt` entry) (`2026-11-20-21-machine-sync-fleet-hardening.md`). The recorded guidance: do T1 first (done), and do not start T4/T7 before T1–T3 make transport trustworthy.
- T8 (federating `ainish-coder` itself) must NOT be completed until the unrelated-history problem is resolved — registering it makes federation permanently "diverged" (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- The unrelated-history decision is an open operator choice with three recorded options: keep Mac's history and re-clone Windows (loses Windows-only content in its 915 commits — 118 fewer files but not a subset), keep Windows's, or reconcile against the shared GitHub `origin`. Nothing was merged or forced; `git merge-base` shows no common ancestor (roots `dda3a90` vs `dc9d7e2`) (`2026-11-20-21-machine-sync-fleet-hardening.md`, `2026-11-21-00-fleet-sync-reliability.md`).
- The concurrency fix `f16b286` is on Mac `main` only; Windows still runs the fixed-filename version (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- The business scheduler ("constantly running agents doing business") does not exist: nothing polls sales, refreshes listings, or drives traffic. It is a new daemon, not a fix to `--machine-sync`. Design gap to work around: `hermes cron create` has no `--profile` flag; profile targeting happens via the `--deliver bot-chat:<profile>` grammar, so a job runs as a generic agent whose output is routed to a profile (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- The consolidation specialist pair (`consolidate-elephant` / `consolidate-goldfish` with their own hermes profiles and skills, compartmentalized from the prime's pair, plus a blocking pre-write gate) is status "implementing"; the next action recorded is T1, the hermes transport (`2026-11-21-00-consolidation-specialist-agents.md`).
- The live consolidation test failed: 7 digests produced but 91 originals left across five folders, tasks failed all six chunks; the review is advisory (runs after writing, does not block); digests sort into the same namespace as records so orientation picks them up; the prime was corrupted (reader invented `status: designing` for a digest; "newest task record" resolved to `DIGEST-tasks-2026-11.md`) (`2026-11-21-00-consolidation-specialist-agents.md`).
- Fleet sync reliability (T1–T7 watcher defects) is "ready": plan written, no code changed for it. Evidence: 45 ok vs 79 failed in `watch.log`; `local-router` failed every attempt through #57 even after restart; `goal-first-trillion` syncs late/irregularly; the watcher was not running current code at one point (pre-fix error after `c105a35` merged); `--auto-commit` committed a half-written skill as `01c379c wip(Mac)`, held `.git/index.lock` during a manual commit, and authored with the wrong identity; `watch.state` reported `failed=0` during continuous failures. T2 (quarantine of failing repos like `local-router`) is the stated immediate mitigation because nothing bounds the retry chain (`2026-11-21-00-fleet-sync-reliability.md`).

Insights:

- `pi_agent_call` is an *agent*, so in a summarizer role it produces agent-shaped preamble ("I'll start with...") that a non-empty check accepts — a length-only gate caused real deletion of 16 files. Only restore-from-git made it recoverable (`2026-11-20-14-context-consolidation.md`).
- Single-shot consolidation hangs the local model: a 44,606-char prompt timed out at 90s/200s/300s while the same payload with a terse instruction answered in 5s; 12,312 chars answered in 12s; hermes answered `HERMES_OK` in 9s on the same host where `pi` timed out. Hence 5-record chunks plus one retry per call, and a merge fallback that keeps partial digests under one heading rather than discarding them (`2026-11-20-14-context-consolidation.md`, `2026-11-21-00-consolidation-specialist-agents.md`).
- `.live.txt` files are date-prefixed and gitignored — a pure date-based deletion rule would delete five of them with no recovery. Only a constructed test caught this; reading the code did not (`2026-11-20-14-context-consolidation.md`).
- `llms.txt` lives inside `memories/` and `plans/` as the folder index, not a record; a legacy `.txt` is not valid UTF-8, so every read needs `errors="replace"` (`2026-11-20-14-context-consolidation.md`).
- The original D1 diagnosis (malformed `/C:/...` Windows temp path) was wrong: `scp` to `windows-128gb:C:/...` succeeds and drive-letter bundle fetches work as constructed. The real cause was a fixed bundle filename racing across concurrent cycles — the source even documented the two directions colliding but not concurrent runs of the same direction (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- Federation delivers refs reliably; the *claims* about them are what lie. Dedup and TCC fallback behave as designed (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- `hermes` profile selection is a subcommand (`hermes profile` state) or `--profile` on the agent invocation — NOT `-p`, which hermes reads as a positional command and rejects (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- A naive `pgrep | wc -l` reads the watcher's delegated child process as a duplicate daemon and invites an unnecessary kill (`2026-11-21-00-fleet-sync-reliability.md`).
- A digest has no `status:` field, so a record-oriented reader invents one — digests and records cannot share one namespace without corrupting orientation (`2026-11-21-00-consolidation-specialist-agents.md`).

Recurring:

- Local-model timeouts on long payloads, and terseness fixing them: recorded for both the consolidation prompt (`2026-11-20-14-context-consolidation.md`) and the specialist-agent test (`2026-11-21-00-consolidation-specialist-agents.md`).
- Machine-sync reporting health while failing: smoke probe always `unverified` and `watch.state` pid stale (D3, D7 in `2026-11-20-21-machine-sync-fleet-hardening.md`); `watch.state` showing `failed=0` during continuous failures and 45 ok / 79 failed totals (`2026-11-21-00-fleet-sync-reliability.md`). "A fleet that lies about its state cannot be debugged" is the stated reason T1–T3 precede policy work (`2026-11-20-21-machine-sync-fleet-hardening.md`).
- The `ainish-coder` unrelated-history problem recurs across both machine-sync records (`2026-11-20-21-machine-sync-fleet-hardening.md`, `2026-11-21-00-fleet-sync-reliability.md`); it blocks T8 and is an operator decision both times.
- `--auto-commit` misbehaving: wrong author identity and index-lock contention (`2026-11-20-21-machine-sync-fleet-hardening.md` D6; `2026-11-21-00-fleet-sync-reliability.md`), plus committing a half-written file (`2026-11-21-00-fleet-sync-reliability.md`). Observed identities differ across records (`Hermes Bot <hermes@bot.local>`, the operator's, and `Nanoboozhoo - embodied by cursor`), so the identity is unreliable rather than fixed-wrong (`2026-11-21-00-consolidation-specialist-agents.md`).
- Consolidation losing or corrupting records unless gated: the 16-file deletion near-miss (`2026-11-20-14-context-consolidation.md`) and the live test's 91 leftover originals plus prime corruption (`2026-11-21-00-consolidation-specialist-agents.md`) — both point at weak or advisory pre-write checks as the shared failure mode.

---

## Accomplished

- One `--context` call now consolidates the record in the background before the learning pass (gated on need, throttled 24h, reported as `provenance.harness.consolidate`) and emits the prime; 440 assertions pass and the work merged as `a22f3c8` (2026-11-21-05-context-prime-consolidation-jobs.md).
- `.agents/jobs/` exists with index, template, and three records (sync-fleet, consolidate-record, learn-harness), distributed by `--rules` without overwriting a target's own records (2026-11-21-05-context-prime-consolidation-jobs.md).
- All six named research sources are now captured as files, including ten canonical EGM reviewer personas vendored; `watch.state` writes atomically and no longer reports `failed=0` before a cycle completes; `--auto-commit` no longer authors as the operator (2026-11-21-05-context-prime-consolidation-jobs.md).
- aiRPC skill landed on branch `skill/airpc`, merged as `22ef539`: the `.agents/` record projects as a tldraw canvas of blocks; Enter on a block fires a call with `block_id`/`path`/`anchor`/`digest`/`prompt`; `bridge.mjs wait` blocks between calls with deadline `--by` exiting 2; acks (`done / needs-you / stale / refused`) paint back onto the canvas. Bridge smoke 8/8 (2026-11-21-14-airpc-skill.md).
- aiRPC lifecycle and cross-repo/query extensions landed on branches `skill/airpc-lifecycle` (merged `48207bc`) and `skill/airpc-tldraw5` (merged `3ca9e46`) — the sources do not map individual features to individual commits. Together these records added: `stop`/`status` subcommands plus `POST /shutdown` and `serve.pid`; restart/resume with manifest/calls/acks intact; `project --from name=path` multi-repo projection with repos inside ids and digests; `kind: "query"` call channel answered in the ack. Extended smoke 28/28 (2026-11-21-14-airpc-lifecycle-demo.md).
- Live demo verified in a browser twice: canvas served by the bridge at http://127.0.0.1:7331, 323 blocks across nine kinds (ainish-coder 311, mai-agentic 12), post-fix reload shows zero page errors (2026-11-21-14-airpc-lifecycle-demo.md).
- `AGENTS.md` at 159 lines (gate `<= 160`), re-signed, chain verified at 66 transitions, re-locked (2026-11-21-05-context-prime-consolidation-jobs.md).

## Unfinished

- The machine watcher has not been restarted, so it still runs pre-fix code; confirm via the new `watch.state` keys (`started=`, `note=`) once the operator restarts it (2026-11-21-05-context-prime-consolidation-jobs.md).
- A partially-digested period still writes a digest: `tasks` covered 1 of 16 records because one chunk failed review; three options recorded in the suggestions file, none chosen (2026-11-21-05-context-prime-consolidation-jobs.md).
- `.agents/jobs/` is inert and not indexed — deliberate, per operator instruction to add no configuration beyond schema and distribution (2026-11-21-05-context-prime-consolidation-jobs.md).
- Consolidation sequencing work is still implementing: 55 originals remain unconsolidated across five folders, every folder over cap; the blocker is period keying (`DIGEST-<folder>-<period>.md` is terminal, so four of five folders consolidated zero; `DIGEST-tasks-2026-11.md` covers 1 record while 15 sit beside it). Next action T1: replace the period lock with a sequence index. Four-agent review panel (fidelity, completeness, coherence per draft) planned but not built (2026-11-21-09-consolidation-panel-sequence.md).
- The demo `serve` (pid 38656, session `demo`) is intentionally still running for operator inspection and must not outlive it; stop via canvas Stop button, `node references/bridge.mjs stop --session demo`, or `kill 38656` (2026-11-21-14-airpc-lifecycle-demo.md).
- Suggestions that outlive their task: projection automation and a distribution decision, in `.agents/suggestions/2026-11-21-14-airpc-followups.md` (2026-11-21-14-airpc-lifecycle-demo.md).
- The canvas drop-in is syntax-checked only, not built against `npm create tldraw@latest`; the skill pins the tldraw quick-start contract so the first agent to wire it re-checks the API surface (2026-11-21-14-airpc-skill.md).

## Insights

- Consolidation was never actually in the context path — the operator's "one command" description was aspirational and the code required two (2026-11-21-05-context-prime-consolidation-jobs.md).
- tldraw 5.6.2 replaced `ShapeUtil.indicator()` with `getIndicatorPath(): Path2D`; the drop-in crashed exactly there. Fixed against the installed package's `.d.ts`, not from memory (2026-11-21-14-airpc-lifecycle-demo.md).
- The digest binding earns its keep: a call carries the digest of the text the user actually reviewed, so edits land `stale` + re-project instead of against a section that moved (2026-11-21-14-airpc-skill.md).
- Valid query acks carried no `new_digest` but `validateAck` demanded one on every `done`, cascading rejections downstream; the protocol says query acks carry none (2026-11-21-14-airpc-lifecycle-demo.md).
- Tests are consumers too: a second `wait` re-delivers an unacked call, so ack before the next wait (2026-11-21-14-airpc-lifecycle-demo.md).
- Paraphrase-as-a-test for goldfish comprehension: an unparaphrasable section IS the finding (2026-11-21-05-context-prime-consolidation-jobs.md).
- Ops facts: `git worktree remove` refuses worktrees of repos with submodules (unregisters but leaves the directory); contract files carry macOS `uchg` — clear it only on task worktree copies, never the main checkout. tldraw's SDK is free in development but needs a license key in production (tldraw.dev/pricing) (2026-11-21-14-airpc-lifecycle-demo.md; 2026-11-21-14-airpc-skill.md).

## Recurring

- Reading the flow before running the smoke caught real bugs in both aiRPC records: the scanner's preamble path pushed one block per line, which would have rejected every manifest with duplicate empty anchors (2026-11-21-14-airpc-lifecycle-demo.md), and `/rpc/wait` re-delivered acked calls while a client-side `--by` abort exited 1 as "bridge unreachable" instead of the deadline's exit 2 (2026-11-21-14-airpc-skill.md).

---

Overview: On 2026-11-21 four tasks landed — moving aiRPC into the distributed skills payload and consolidating `.agents/suggestions`, `.agents/comms`, and `.agents/memories` into sequence digests (`DIGEST-suggestions-01.md`, `DIGEST-comms-01.md`, `DIGEST-memories-01.md`).

## Accomplished

- aiRPC moved from `.agents/skills/` to `skills-to-distribute/skills/` as four 100% renames; branch `skill/airpc-distribute` merged (`2f23e86`, commit `07416aa`); dist suite 440 pass / 1 fail identical to the clean-`main` baseline (no new failures); demo bridge stopped (pid 38656), port 7331 free, no bridge processes (2026-11-21-15-airpc-distribute.md).
- ~5.6G of regenerable caches freed (three updater payloads; puppeteer, codex-runtimes, opencode, chrome-devtools-mcp, act), turning nondeterministic `No space left on device` failures of `scripts/test-pqc-dist.sh` into a stable baseline (2026-11-21-15-airpc-distribute.md).
- `DIGEST-suggestions-01.md` (`ainish/context-digest/v1`) landed from 3 follow-up records: the manual drafter v1 failed fidelity twice (Recurring synthesis overreach — `--cap` does warn, and several "Settled by:" lines are measurements, not decisions), then passed the 3-member `CONSOLIDATE_PANEL` 3/3 and was committed (`0a01084`); a concurrent background `context-consolidate` pass then clobbered the file and its draft failed coherence (no period arc; test-only runs read as production use), so the landed digest is the reconciled merge — the background draft's granularity plus this run's arc ("hardening and verification phase") and test-only framing, plus one hedging fix ("payload size is not the failure driver" → "on this evidence size is unlikely...") — which passed the final panel 3/3 (`VERDICT: pass`, `GAP: none`). `0a01084` is the pre-clobber v1 commit; the source records no commit SHA for the merged version (2026-11-21-15-consolidate-suggestions-2026-11.md).
- `DIGEST-comms-01.md` landed from 4 day ledgers (2026-11-11 … 2026-11-15); all 15 delegated-reviewer findings fixed and content-checked (59 source citations, `records_consolidated: 4`); both cut excerpt tails read in full from disk first (2026-11-21-16-consolidate-comms-2026-11.md).
- `DIGEST-memories-01.md` landed from 2 memory records; all three prior-reviewer gaps (fidelity, completeness, coherence) addressed and re-checked against source text (42 + 17 citations); cut tail of `2026-11-07-memory.txt` read in full from disk first (2026-11-21-18-consolidate-memories-2026-11.md).
- In all three consolidations, removal was limited to the exact `sources:` files, after the digest was written, each recoverable via `git show <commit>^:<path>` (2026-11-21-15-consolidate-suggestions-2026-11.md, 2026-11-21-16-consolidate-comms-2026-11.md, 2026-11-21-18-consolidate-memories-2026-11.md).

## Unfinished

- Pre-existing dist attribution test failure: "a tool-authored commit is re-authored as the operator" wants `embodied by cursor` but gets `embodied by claudecode` (440 pass / 1 fail at baseline, before and after the aiRPC move). Not fixed — the subsystem is a sibling session's boundary; recorded as `.agents/suggestions/2026-11-21-15-attribution-table-test-drift.md`; owner decides which literal is canonical (2026-11-21-15-airpc-distribute.md).
- Internal disk at 5.4G free (99%) after cleanup; further cleanup scope is the operator's call ("Orca item 1") (2026-11-21-15-airpc-distribute.md).
- 12 open follow-ups carried in `DIGEST-suggestions-01.md`'s Unfinished section — requirements only, not done (2026-11-21-15-consolidate-suggestions-2026-11.md).
- `.agents/suggestions/2026-11-21-15-background-pass-clobber.md` filed for the background-pass overwrite incident; resolution not recorded (2026-11-21-15-consolidate-suggestions-2026-11.md).
- `.agents/comms/DIGEST-comms-02.md` (2026-11-17 … 2026-11-18 "part 2", 2 sources) was written by a concurrent background pass and left uncommitted for its own writer to land; its 2 source records were left untouched (2026-11-21-16-consolidate-comms-2026-11.md).
- Open methodological question: one writer per mutation boundary does not hold between a manual consolidation run and the background `context-consolidate` pass — observed twice in one day; no fix recorded (2026-11-21-15-consolidate-suggestions-2026-11.md, 2026-11-21-16-consolidate-comms-2026-11.md).

## Insights

- In consolidation digests, every *invention* reviewers found was a conclusion the sources did not carry (a superseded blocker, a quantifier, a possessive), while concrete numbers, hashes and paths all checked out — but synthesis errors were not the only failure mode: the comms review also found 5 omissions and the memories review a completeness gap (2026-11-21-15-consolidate-suggestions-2026-11.md, 2026-11-21-16-consolidate-comms-2026-11.md, 2026-11-21-18-consolidate-memories-2026-11.md).
- Reviewers check claims but do not replace reading the record: a fidelity reviewer's "accurate count" was itself one off; counting from the source text beat trusting the review (2026-11-21-16-consolidate-comms-2026-11.md).
- Adjacent-topic entries in these records are distinct events — a prior fidelity error came from merging two adjacent entries (SECURITY split across four packs vs `context-orchestration` retirement). Cite the entry, not the neighbourhood (2026-11-21-18-consolidate-memories-2026-11.md).
- Absence from other records' `sources:` metadata is not evidence a file is destroyed — a fail-closed check flagged two sources as possibly destroyed when they were simply uncited; verify existence by reading the filesystem (2026-11-21-18-consolidate-memories-2026-11.md).
- A full internal disk (165M free) causes nondeterministic fixture-write failures; model caches (huggingface/modelscope/suno/uv) are symlinks to the external 1TB drive, so deleting there frees nothing on the internal disk (2026-11-21-15-airpc-distribute.md).
- Cut prompt excerpts must be read in full from disk before drafting — done in both the comms and memories consolidations, preventing lost-tail facts (2026-11-21-16-consolidate-comms-2026-11.md, 2026-11-21-18-consolidate-memories-2026-11.md).
- `run_context_consolidate`'s automated gate abandons a period after a second failed review; an operator-directed run instead kept fixing and re-checking until clean — a stated deviation (2026-11-21-15-consolidate-suggestions-2026-11.md).
- Deviations from standard process (panel composition, skipped re-review rounds) were stated, not hidden, in all three consolidation runs (2026-11-21-15-consolidate-suggestions-2026-11.md, 2026-11-21-16-consolidate-comms-2026-11.md, 2026-11-21-18-consolidate-memories-2026-11.md).

## Recurring

- Background `context-consolidate` passes interleaving with manual runs in the same folder: one clobbered `DIGEST-suggestions-01.md` mid-task (reconciled manually); another interleaved via `_digest_path`'s next-index naming in comms. Same failure twice on 2026-11-21 (2026-11-21-15-consolidate-suggestions-2026-11.md, 2026-11-21-16-consolidate-comms-2026-11.md).
- Invented conclusions (synthesis overreach) as a fidelity risk, distinct from misstated facts — every invention was a conclusion the sources did not carry, while concrete facts checked out; observed independently in the suggestions and comms reviews (2026-11-21-15-consolidate-suggestions-2026-11.md, 2026-11-21-16-consolidate-comms-2026-11.md).
- Writing the digest before any removal and limiting removal to the exact `sources:` files — held in every round of all three consolidations (2026-11-21-15-consolidate-suggestions-2026-11.md, 2026-11-21-16-consolidate-comms-2026-11.md, 2026-11-21-18-consolidate-memories-2026-11.md).

---

## Overview
November 2026 brought the universal contract up to a Git & PR protocol, harness-agnostic authorship with fast rules tooling, two-way Mac/Windows repo federation via merged PRs #7/#8, and prompt/license governance with a canonical license CI gate. All four tasks recorded status done; the residual live threads are two unmerged PRs, a deferred P0 consolidation, one operator license decision, and one pre-existing verifier bug.

## Accomplished
- Git & Pull Request Protocol added to `AGENTS.md` (Branching & Sync, Scoped Changes & Security, Pull Requests, Review & CI Loop), with Non-negotiable #1 and `## Worktrees` reconciled to PR-based delivery; contract verified at 158 lines (gate ≤160), all test-pinned phrases present, five contract files re-locked (444 + `uchg`), worktree merged to `main` and removed (2026-11-22-00-git-pr-protocol.md).
- Commit authorship standardized to `Nanoboozhoo embodied by: {harness}` with the harness always env/author-detected, never hardcoded; identity guard, dist suite, machine sync, and fleet auto-commit updated in lockstep (2026-11-22-13-fast-rules-tooling.md).
- `run_eval_patch` implemented in `src/context/engine.py`, fixing the gate's `NameError` crash; gate now accepts any signature envelope matching canonical bytes and scores 0–1; `bin/ainish-context gate --summary` → GREEN (2026-11-22-13-fast-rules-tooling.md).
- `snapshot_canonical_contract` now unlocks canonical artifacts before signing, verifies the digest, re-locks, and fails closed; `--lock-rules` no longer swallows signing failures (2026-11-22-13-fast-rules-tooling.md).
- Rules deploy fast path landed: post-commit hook skips fleet sync for non-rules commits, staleness decided by deployed content hashes instead of commit SHA; fleet registry pruned 57 → 10 real targets, all 10 synced and current (11 after later expansion), 0 stale (2026-11-22-13-fast-rules-tooling.md; 2026-11-22-14-federation-profile-cleanup.md).
- Hermes profile provisioning removed from `--rules` (now `--context`-only); no provisioning references remain in `src`/`bin` (2026-11-22-14-federation-profile-cleanup.md).
- PRs `nbiish/ainish-coder#7` (`chore/tooling-federation-release`) and `#8` (`fix/watcher-no-autocommit`) merged to `origin/main` with all four CI checks green on each (2026-11-22-14-federation-profile-cleanup.md).
- Bidirectional federation verified: Windows `ainish-coder` re-cloned from a Mac bundle to canonical `D:\Code\ainish-coder` (signer key and `.claude` preserved), `--machine-sync --both` fast-forwarded both machines to `21517fa`, and a Windows-side commit had previously arrived on Mac proving reverse direction (2026-11-22-14-federation-profile-cleanup.md).
- `machine_watch.sh` respects a `.agents/no-watcher-autocommit` marker (sync `--both`, never `--auto-commit`); `local-router` link removed from `links.txt`, `ainish-coder` → `windows-128gb` added (2026-11-22-14-federation-profile-cleanup.md).
- `bin/security_gate.py` CI fixes landed: digest parsed from `sha256sum` format; `os.open` atomic locks no longer false-positive the unsanitized-path rule (2026-11-22-14-federation-profile-cleanup.md).
- Prompt governance rules 13 (versioned prompt templates, prune stale rules) and 14 (legal text canonical, CI byte gate, `critical.md` §7) added to `AGENTS.md` at 159/160 lines; full operator policy preserved verbatim in `.agents/templates/prompt-context-governance.md` (`ainish/prompt-policy/v1`, v1.0.0) (2026-11-23-18-prompt-license-governance.md).
- Canonical license sync gate landed in-tree: `.github/workflows/license-sync.yml` fails PRs when local `LICENSE` differs from canonical (`cmp -s`), checks metadata declarations for foreign license names, and on push/weekly opens integration PRs with `chore(license): sync canonical license from license-for-all-works`; canonical `critical.md` §1.3/§1.4/§6/§7 updated; this repo's `LICENSE` now SHA-256 `6b18aab7…` (was `1d330ecc…`), byte-identical to canonical (2026-11-23-18-prompt-license-governance.md).
- Dist suite grown and green: 445 assertions (baseline 440 pass / 1 fail → 441 → 445); contract history audit PASS with 66 hash-chained transitions and ML-DSA-65 signature VERIFIED (2026-11-22-00-git-pr-protocol.md; 2026-11-22-13-fast-rules-tooling.md; 2026-11-23-18-prompt-license-governance.md).

## Unfinished
- PRs `nbiish/ainish-coder#12` and `nbiish/license-for-all-works#6` (prompt/license governance) are open, awaiting human approval; merging is deliberately not agent-authorized (2026-11-23-18-prompt-license-governance.md).
- P0 tasks/plans consolidation is deferred — the operator owns it as a separate task (2026-11-23-18-prompt-license-governance.md).
- `working-LICENSE` vs production `LICENSE` divergence remains an operator promotion decision; `working-LICENSE` is byte-identical to canonical in this repo (2026-11-23-18-prompt-license-governance.md).
- `ainish-coder --verify-rules` integrity mismatch is pre-existing and unfixed: `AGENTS.md.sha256` carries a `  AGENTS.md` suffix that the verifier's `tr -d '[:space:]'` leaves behind; identical format at baseline commit `0727f1e` (2026-11-22-00-git-pr-protocol.md). (The related `--lock-rules` silent-failure issue from the same record was addressed by the unlock-before-sign change in 2026-11-22-13-fast-rules-tooling.md.)
- The 915 Windows-only commits were never migrated into Mac history; the operator confirmed that work was redone on Mac and the old Windows checkout plus scratch dirs were deleted. Thread closed by that confirmation, but the history is permanently absent (2026-11-22-14-federation-profile-cleanup.md).

## Insights
- The dist suite pins exact contract phrases; compressing prose to fit the 160-line gate paraphrased pinned strings and the suite caught it — restore exact phrases after any contract compression (2026-11-22-00-git-pr-protocol.md; 2026-11-23-18-prompt-license-governance.md also had to reclaim lines from preambles).
- Canonical contract artifacts locked `444` + `uchg` silently break signing flows that suppress output — unlock before re-signing, re-lock after (2026-11-22-00-git-pr-protocol.md).
- A watcher-managed link can fail every cycle and starve other repos while auto-committing mid-write (`local-router` did); repos can opt out of watcher auto-commits with an `.agents/no-watcher-autocommit` marker while still receiving `--both` sync (2026-11-22-14-federation-profile-cleanup.md).
- Historical COMMS/plans/memory records retain old author strings on purpose — they are evidence of past state, not live tooling to update (2026-11-22-13-fast-rules-tooling.md).
- Signing was deliberately kept per operator decision; friction was removed at the tooling layer, not by weakening security (2026-11-22-13-fast-rules-tooling.md).
- Outward-facing delivery (push/PR) happens only when authorized for that task; otherwise delivery stays local via worktree merge-back (2026-11-22-00-git-pr-protocol.md; 2026-11-22-13-fast-rules-tooling.md). Separately, the contract now specifies PR-based delivery with no self-merge, human approval, and green CI (2026-11-22-00-git-pr-protocol.md).
- Windows↔Mac federation is proven in both directions; both sides converge on `main` with exactly one local branch each (2026-11-22-14-federation-profile-cleanup.md).

## Recurring
- The ≤160-line contract gate forces prose compression in every contract-touching task (158 lines in 2026-11-22-00-git-pr-protocol.md, 159 in 2026-11-23-18-prompt-license-governance.md), and each time test-pinned phrases must survive the squeeze.
- Canonical re-sign + re-lock (444/`uchg`) is a required step after any contract/canonical change, and its pitfalls recur (2026-11-22-00-git-pr-protocol.md; 2026-11-22-13-fast-rules-tooling.md).
- Verification triple is the standing evidence pattern: `scripts/test-pqc-dist.sh` (441→445 assertions), `ainish-context gate --summary` (GREEN), and `audit contract --verify-history` (66 transitions, signature VERIFIED) — run together in 2026-11-22-13-fast-rules-tooling.md and 2026-11-23-18-prompt-license-governance.md.
- PR-based delivery recurs across these tasks, though the records differ on its specifics: the contract now mandates no self-merge, human approval, and green CI (2026-11-22-00-git-pr-protocol.md); PRs #7/#8 are recorded as merged with four green CI checks each, with no approver recorded (2026-11-22-14-federation-profile-cleanup.md); PRs #12/#6 are left open awaiting human approval (2026-11-23-18-prompt-license-governance.md).

---

## Accomplished

- Self-improving Hermes `context-elephant`/`context-goldfish` profile setup and machine-sync parity landed on `feat/context-hermes-sync` (status done): `--context-setup` created/updated 6 Hermes profiles, restored `http://127.0.0.1:11434/v1` in root `config.yaml`, wired `pi` `models.json`; `pi --list-models` shows `local-router/fallback-models` and `--context` smoke served `hermes:context-elephant` and 3-step `hermes:context-goldfish` via `:11434` [2026-11-24-21-context-hermes-and-machine-sync.md].
- `--machine-sync --doctor` verified working: `mac-18gb` SSH reachable, both Windows links (`D:/Code/ainish-coder`, `D:/Workspace/local-router` -> `mac-18gb`), `6/6` Hermes profiles, `pi` `models.json`, `:11434` online; missing-repo `--machine-link` hint and `--machine-sync --doctor --json` covered by tests [2026-11-24-21-context-hermes-and-machine-sync.md].
- Machine-sync suite green at 63/63 including Windows UTC `--latest` formatting; `bash -n` on all touched scripts exit 0; `test_context_injection.HermesContextRuntimeTest` + `GoldfishIsolationTest` 10/10 [2026-11-24-21-context-hermes-and-machine-sync.md].
- Paired `local-router` PR #21 (https://github.com/nbiish/local-router/pull/21): `node bin/agents-doctor.js` confirms `6/6 ctx profiles` and `pi: present` [2026-11-24-21-context-hermes-and-machine-sync.md].
- Cross-machine Chain of Draft federation landed on `feat/agents-federation-cod` (status done): gitignored, OS-locked, agent-read-only `.agents/federation/{date}.md` exchanged by `--machine-sync` inside FIPS 203 ML-KEM-768 + FIPS 204 ML-DSA-65 + AES-256-GCM envelopes, failing closed on `git check-ignore`, fingerprint mismatch, or missing PQC primitives with no plaintext downgrade [2026-11-25-13-agents-federation-cod.md].
- `AGENTS.md` integration guidance landed (158 lines, within ≤160-line gate), canonically ML-DSA-65 signed; `ainish-context audit contract --threshold 1` + `--verify-history` PASS with 66 hash-chained transitions verified [2026-11-25-13-agents-federation-cod.md].
- Federation test suites green: `test_federation_pqc.py` 3/3 (PQC roundtrip, tampered ciphertext and peer fingerprint change fail-closed refusal, secret/PII/bidi/sensitive-path scrubbing, read-only lock); `OrientationSectionTest` 17/17 including federation CoD and sibling-branch orientation surfacing; `test-machine-sync.sh` 67/67 including §19 PQC read-only exchange, union-merge, clean git trees, unenrolled-repo protection; `test-pqc-dist.sh` 457/457 isolated [2026-11-25-13-agents-federation-cod.md].
- Documented `ainish-coder --context-{seed,status,learn,rollback,promote}` verbs now reachable on `fix/context-cli-wiring` (status done) — previously documented but rejected as `Unknown command`; smoke 5/5 flags reach matching engine subcommands, `--help` lists all five [2026-11-25-15-context-cli-wiring.md].
- Orientation `- gate:` line made self-describing (stale marked for any colour, recorded tests result shown, plain form preserved) without schema, signature, or exit-code change; `test_context_injection.py` 109/109 including 3 new gate-line tests; `test-pqc-dist.sh` 457/457 confirms the help.sh addition disturbs no phrase pins [2026-11-25-15-context-cli-wiring.md].
- Context-tooling session verification: `ainish-coder --context` full envelope in 76s with all four sections sourced through `local-router/fallback-models`, `--retrieval-only` in 2.7s, live `ainish-context gate` GREEN [2026-11-25-15-context-cli-wiring.md].

## Unfinished

- `wsl-94gb` SSH is unreachable; `--machine-sync --doctor` exits 1 on it as expected, so that machine's link state is unverified [2026-11-24-21-context-hermes-and-machine-sync.md].
- `test-pqc-dist.sh` on the 2026-11-24-21 branch still has 3 pre-existing baseline assertion failures unrelated to the diff (`AGENTS.md` and `LICENSE` untouched) [2026-11-24-21-context-hermes-and-machine-sync.md].
- `test_shared_rules_file_is_loaded_and_strip_ansi` fails on untouched `main` checkout (pre-existing baseline, not fixed by any of these tasks) [2026-11-25-15-context-cli-wiring.md].
- `test_generation_refuses_to_clobber_a_vault` and `test_wikilinks_survive_a_refused_run` in `test_wiki_graph.py` fail — the documented pre-existing baseline first recorded 2026-11-24-21, unchanged as of 2026-11-25 [2026-11-25-15-context-cli-wiring.md].
- A full `ainish-coder --context` verification run during the federation task was cancelled because it prompted interactively for a vault passphrase; repo state was verified directly from files and git instead, so the interactive path remains unexercised on that host [2026-11-25-13-agents-federation-cod.md].

## Insights

- Six failures in full `unittest discover` (`test_wiki_graph.py`, `test_gate_ready.py`, `RoleModelSeparationTest`) were previously hidden behind the deleted `rag.py` and surfaced only after that deletion — they are baseline, not regressions of the 2026-11-24-21 diff [2026-11-24-21-context-hermes-and-machine-sync.md].
- A recorded `gate: RED (anchor 100%)` in a context envelope can be a full-tests verdict containing only pre-existing failures; the 2026-11-25-15 gate-line change exists to make that provenance self-describing [2026-11-25-15-context-cli-wiring.md].
- The federation CoD channel is deliberately fail-closed with no plaintext downgrade: `git check-ignore` non-enrollment, fingerprint mismatch, or missing PQC primitives all refuse rather than degrade [2026-11-25-13-agents-federation-cod.md].
- `ainish-coder --context` can block on an interactive vault passphrase prompt on some hosts; per `AGENTS.md` the run can be cancelled and verification done from files and git [2026-11-25-13-agents-federation-cod.md].
- Both landed branches are additive/backward-compatible by design: no schema, signature, or exit-code change on existing surfaces [2026-11-25-13-agents-federation-cod.md, 2026-11-25-15-context-cli-wiring.md].
- Rebuild verdict `no-rebuild-needed` on both 2026-11-25 tasks — the repo ships no long-running server [2026-11-25-13-agents-federation-cod.md, 2026-11-25-15-context-cli-wiring.md].

## Recurring

- Pre-existing baseline test failures recur in every closeout: 3 in `test-pqc-dist.sh` (2026-11-24-21), the `test_wiki_graph.py`/`test_gate_ready.py` set (2026-11-24-21, 2026-11-25-13, 2026-11-25-15), each task verifying they are unchanged from `main` rather than caused by its own diff [2026-11-24-21, 2026-11-25-13, 2026-11-25-15 records].
- Fail-closed refusal as a design pattern recurs: PQC federation refuses on any integrity/identity mismatch, and context generation refuses to clobber a vault [2026-11-25-13-agents-federation-cod.md, 2026-11-25-15-context-cli-wiring.md].
- Multi-machine state verified through `--machine-sync --doctor` (mac-18gb, Windows links, Hermes profiles) as the recurring health gate across these tasks [2026-11-24-21-context-hermes-and-machine-sync.md].
