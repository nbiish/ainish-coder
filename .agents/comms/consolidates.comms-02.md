---
format: ainish/context-digest/v1
schema: consolidates.{naming}.md
folder: comms
period: rollup
records_consolidated: 3
consolidated_at: 2026-11-27T02:22:26.845692+00:00
profiles: [consolidate-elephant, consolidate-structural, consolidate-archivist, consolidate-goldfish]
transports: [hermes]
sources:
  - DIGEST-comms-01.md
  - DIGEST-comms-02.md
  - consolidates.2026-11-01.md
---

# Digest — `.agents/comms`, rollup

This digest replaces 3 record(s) from rollup. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
Covers five days of `.agents/comms` records (2026-11-17 – 2026-11-21): federation discoverability and the context-priming harness, single-command `--context` and wiki pseudo-skills, a secrets/CI security purge and fail-open audit-gate fix, the context-agent correctness push retiring `src/rag/` into `src/context/engine.py`, identity-trailer/contract-identity tooling, context consolidation runs, and the aiRPC skill with a live tldraw lifecycle demo — plus a disk-full incident and open attribution drift.

## Accomplished

Federation discoverability (2026-11-17-team.md):
- `ainish-rag --help` gained the machine-federation block (`--machine-link … --watch`, `--machine-sync --latest/--branches`, `--machine-watch --status`, registry paths) and `AGENTS.md` a pointer row; stale record `2026-11-15-09-watch-suggestions` corrected from `implementing` to `done (merged e08333a)`. Assertions 302 → 306 in `scripts/test-pqc-dist.sh`; `--help | grep -c machine` 0 → 6; `AGENTS.md` held at 160 lines.

Context-priming-master (2026-11-17-team.md):
- Research dossier `research/context-priming-master/` (9 documents, ~1,950 lines; arXiv 2610.14224 HTML, both YouTube transcripts via `youtube-transcript-api`, google-research/harness2 read at source). Plan `.agents/plans/2026-11-17-19-context-priming-master.md` (ready, 15 todos). Phase 0 (`phase0.py`, `phase0b_monotonicity.py`) found the five proposed acceptance signals self-fulfilling (rho >= 0.9 up to 1.000) and rebuilt the gate on an external referent (commit-subject vocabulary), findings in `08-phase0-findings.md`, as-built `09-as-built.md`.
- Harness shipped and merged 4979302: `src/rag/context_harness.py` (916 lines), five verbs (`context-seed/-status/-learn/-rollback/-promote`), `provenance.harness`, seeding in `deploy_rules_bundle`, `_skill_learned` beside `_skill_mandatory` so `src/deploy_skills.sh:181` cannot delete a promoted pack. Verified 331 assertions (306 + 25); byte-identical no-profile primes except the additive provenance block; rollback restored fingerprint cf19d36708eaa433 exactly; staging-only learned skills.

Single-command context (2026-11-18-team.md):
- `--context` reads `AGENTS.md`/`llms.txt` as `contract` kind, reports contract digest and gate verdict in `orientation`, spawns a throttled detached learning pass (≤ once/6h). Merged 8321849; 342 assertions (331 + 11); contract top hit at 1.00; `autolearn.spawned` true then suppressed with named remaining minutes.

Wiki pseudo-skills (2026-11-18-team.md):
- Corpus widened 52 nodes/10 files → 414 nodes/~150 files (newest-2-per-folder cap removed, research recursive, `.agents/wiki/skills/` added with 6 cited pseudo-skills, `context-skill` authoring plus validator; `.gitignore` `!/.agents/wiki/`). Merged 748cb8a; 354 assertions (344 + 10); answerability 4/8 → 8/8 with zero regressions; latency cold 309ms, warm 14ms.

Security purge and CI (2026-11-18-team.md):
- git filter-repo purge: `src/rag/.agents/audit/signer.mldsa65.priv` removed from every commit, two Firecrawl keys replaced; 980 commits rewritten, 5 local branches force-pushed, 13 remote branches verified clean. `scan_secrets.sh` rewritten (`git grep`, history private-key blocks); `security.yml` distinguishes advisory-DB parse errors; `.agents/canonical/AGENTS.md.sha256` regenerated; `commit-identity-guard.sh` recognises `ainish-coder bot` and amends with `-S`. Merged f3b3a1c; two green Actions runs after 14 failures; 359 assertions (354 + 5).

Fail-open audit gate (2026-11-18-team.md):
- Stale scan #197 (commit `ca947fe7`) exposed a YAML-heredoc IndentationError fail-open in the #198 fix while cargo-audit reported RUSTSEC-2026-0385 in `ctutils` 0.4.2. Fixed via `.github/scripts/check_cargo_audit.py` (fail closed, exit 2 when undeterminable), `ctutils` → 0.4.4, cargo-audit 0.21.2 → 0.23.0. Merged 606a5a4; Run #44347727929 all jobs success; 365 assertions (359 + 5 pinning clean=0, vulnerable=1, empty=2, unparseable=2); live crypto unchanged (vault fingerprints sha3:2e0de6da664cdae5 / ef94050ec58bb911).

Context-agent correctness and RAG retirement (2026-11-19-team.md, 2026-11-19-14, 2026-11-19-15):
- `ainish-coder --context` is the entry point, `ainish-rag` a shim; corpus whole (164 files, 411 nodes), `base_settings()` from `BASE_PROFILE`; shared-vocabulary edges bounded (42,216 → 4,220); `KIND_INTENT` boosts and overrides `skip_retrieval`; task records with `--task-record`/`--outcome` and `_coverage_loss_guard`. `src/rag/` became `src/context/engine.py`; ~7k-line Rust crate deleted; `ainish-context` launcher; ML-DSA-65 over a 32-byte seed. 387 assertions; `probe_corpus.py` expected-kind-in-top-5 4/11 → 10/11; rollback restored fingerprint 4e02eea77ff7f9d9.

Identity trailer and contract identity (2026-11-20-team.md, 2026-11-20-09, -10):
- `commit-msg` hook strips 17-harness attribution (`scripts/harness-attribution.txt`) pre-commit; Rule 4 states the `Nanoboozhoo - embodied by {agent harness}` form; `--rules` deploys the table, stripper, and guards to a target's `.agents/bin/`. 397 → 407 assertions; history rewrite 0 trailers across 31 unpushed commits, tree hash `a1e6f70e3ef6` unchanged; contract re-signed, re-locked (`uchg`).

Context consolidation (2026-11-20-team.md, 2026-11-20-11, -14):
- Context section names the read folders and points at `.agents/llms.txt`; `AGENTS.md` at 160 lines, all eleven non-negotiables present. `context-consolidate` walks five folders, protects 3 newest, chunks 5-at-a-time, goldfish-reviews, writes `DIGEST-<folder>-<period>.md`, removes summarised records (first run: `.agents/suggestions` 19 files → 3 originals + 1 digest). `_digest_is_usable` requires 200+ chars, 3 of 4 sections, no promise-opener. 426 assertions. Specialized-agents pack shipped.

aiRPC skill and lifecycle demo (2026-11-21-team.md, tasks 2026-11-21-14/-15):
- Skill at `.agents/skills/aiRPC/` (`SKILL.md`, `references/protocol.md` v1, `bridge.mjs`, `canvas-app.tsx`), bridge smoke 8/8, merged 22ef539. Live demo on 127.0.0.1:7331: tldraw 5.6.2, 323 blocks across two repos (ainish-coder 311, mai-agentic 12), stop/status/shutdown, restart-resume, multi-repo `project --from`, `kind: "query"`; smoke 28/28, browser-verified twice with `errors: []`; merged 48207bc, 3ca9e46. Bridge stopped (pid 38656, port free); `aiRPC/` moved to `skills-to-distribute/skills/aiRPC/` (07416aa, merged 2f23e86). `DIGEST-suggestions-01.md` (ainish/context-digest/v1) consolidated 3 suggestion records, sources removed via `git rm` (recoverable via `git show 0a01084^:<path>`).

## Unfinished

- Signing anchor drift: live local signing seed `69e7233d…` ≠ committed trust anchor `d98405ea3684…`; `audit verify` fails on two artefacts. Explicitly not fixed (2026-11-17-team.md, 2026-11-18-team.md).
- machine-sync: plan + task record only; 8 live-watcher defects — 30% cycle failure rate, always-unverified smoke probe, untracked files blocking fast-forward, ignored binaries with no transport, auto-commit using operator identity, stale watcher pid, tool repo not federated, and one 8th defect not named in the visible text (2026-11-20-team.md).
- Harness-attribution table to be extended as other harnesses' signing behaviour is learned (2026-11-20-team.md, 2026-11-20-09).
- Follow-up suggestion files still live outside comms: `2026-11-19-15-context-agent-followups.md`, `2026-11-19-16-retire-rag-followups.md`, `2026-11-20-15-identity-trailer-followups.md` (2026-11-20-16/-17/-21 were consolidated into `DIGEST-suggestions-01.md`, recoverable via `git show 0a01084^:<path>`) (2026-11-19-team.md, 2026-11-20-team.md, 2026-11-21-team.md).
- aiRPC follow-ups (`2026-11-21-14-airpc-followups.md`): item 1 (projection automation) and item 3 (distribution) open; only item 2 resolved by the lifecycle demo (2026-11-21-team.md).
- Sibling attribution drift: `scripts/test-pqc-dist.sh` has one red assertion ("a tool-authored commit is re-authored as the operator": got `embodied by claudecode`, want `embodied by cursor`) from sibling merge `7685720`; left to its owner per one-writer-per-boundary (2026-11-21-team.md; `.agents/suggestions/2026-11-21-15-attribution-table-test-drift.md`).
- Orca items opened for the aiRPC deliverable and the disk decision; status not recorded (2026-11-21-team.md).
- `canvas-app.tsx` is syntax-checked only — no tldraw scaffold built on this host (2026-11-21-team.md).
- New finding filed: `.agents/suggestions/2026-11-21-15-background-pass-clobber.md` (background pass clobber) (2026-11-21-team.md).
- omp async daemon broker failed to start during distribute (likely disk-full aftermath); backgrounded bash jobs still ran (2026-11-21-team.md).

## Insights

- Acceptance signals can be self-fulfilling: Phase 0 measured rho up to 1.000 between each proposed signal and its own knob, so the gate was rebuilt on an external referent and refuses when none exists (2026-11-17-team.md, `08-phase0-findings.md`, `09-as-built.md`).
- A YAML heredoc (`python3 - <<'PY'` in a workflow `run:` block) can fail open: indentation breaks Python silently and empty output mapped to "unparseable" exits 0 while the real check reports a vulnerability; the fix moved the decision to a fail-closed script (2026-11-18-team.md).
- Editing `AGENTS.md` without regenerating `.agents/canonical/AGENTS.md.sha256` correctly fails the compliance gate (2026-11-18-team.md).
- A stale CI notification can still be worth verifying — scan #197 was noise but uncovered the fail-open audit gate (2026-11-18-team.md).
- yt-dlp rate-limits (429) on YouTube transcripts; `youtube-transcript-api` was the working fallback (2026-11-17-team.md).
- The profile always beats the engine: the 2026-11-18 whole-corpus fix shipped disabled because `BASE_PROFILE` said 2 artifacts while the engine said unlimited, and the test suite pinned the bug by expecting 8 (2026-11-19-team.md).
- `--rag` had been broken since `deploy_commands.sh` began clobbering `SCRIPT_DIR` at source time, which also meant `--rules` seeding never ran (2026-11-19-team.md).
- Resolving the canonical root from a worktree writes to the main checkout: `context-seed`/`context-learn` state landed on a branch nobody was on; `audit lock --update` from a worktree rewrote the main checkout's manifest (2026-11-19-team.md).
- All four historical task records name merge SHAs that no longer exist; the record is the referent and corroboration is reported, not required (2026-11-19-team.md).
- `max_wiki_pages: 0` means all, not "index nothing"; the learner had proposed narrowing on every run (2026-11-19-team.md).
- A rollback insight begins "Rollback must restore the skills tree of t" and is cut off in the reproduced source; complete wording lives in `consolidates.2026-11-01.md` and its git history — no further rollback guidance asserted here (2026-11-19-team.md).

## Recurring

- The `AGENTS.md` 160-line gate held across every merge of 2026-11-17/-18 (federation row, single-command paragraph "paid for by compression", harness work) and again in the 2026-11-20 internals removal (159 → 160, "the honest size") (2026-11-17-team.md, 2026-11-18-team.md, 2026-11-20-team.md).
- Every assertion-adding merge carried its own named baseline: `scripts/test-pqc-dist.sh` 302 → 306 → 331 → 342 → 354 → 359 → 365 (six increases in two days), continuing through 387, 397, 407, 426 in the following days (2026-11-17-team.md, 2026-11-18-team.md, 2026-11-19-team.md, 2026-11-20-team.md).
- Commit-identity/attribution drift recurred until the guard, then the `commit-msg` hook and Rule 4 were built for it — yet one sibling attribution drift remains red in `test-pqc-dist.sh` (2026-11-18-team.md, 2026-11-20-team.md, 2026-11-21-team.md).
- Follow-up threads outliving their deliverables: every major push (federation, context-priming, context-agent, retire-rag, identity-trailer, aiRPC) left `.agents/suggestions/2026-*-followups.md` files still open outside comms (2026-11-19-team.md, 2026-11-20-team.md, 2026-11-21-team.md).
- Disk-full fallout appearing in more than one record: the failed omp daemon broker during distribute and the open disk decision item trace to the same incident window (2026-11-21-team.md).
