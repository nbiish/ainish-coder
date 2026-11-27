---
format: ainish/context-digest/v1
schema: consolidates.{naming}.md
folder: suggestions
period: 2026-11+
records_consolidated: 7
consolidated_at: 2026-11-26T23:35:03.555124+00:00
profiles: [consolidate-elephant, consolidate-structural, consolidate-goldfish, consolidate-archivist]
transports: [hermes]
sources:
  - DIGEST-suggestions-01.md
  - DIGEST-suggestions-2026-11.md
  - 2026-11-21-03-consolidation-gate-followups.md
  - 2026-11-21-09-context-consolidation-jobs-followups.md
  - 2026-11-21-14-airpc-followups.md
  - 2026-11-21-15-attribution-table-test-drift.md
  - 2026-11-21-15-background-pass-clobber.md
---

# Digest — `.agents/suggestions`, 2026-11+

This digest replaces 7 record(s) from 2026-11+. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
Period 2026-11+ covers contract/identity hardening and verification, retrieval/federation/CLI fixes, consolidation tooling built and iterated after several real-world failures, and two incident-level findings: a background pass clobbering a manual digest and consolidation digests losing content to excerpt cuts and partial reviews. All records remain recoverable from git under the filenames cited; this digest is not exhaustive (see Unfinished).

## Accomplished

- Restored the nine advisory masters to `AGENTS.md` as dual-expertise pairs with an on-the-fly expert constitution; added `.agents/templates/masters.md` as the canonical definition, emitted pairs inline in `context-packet.sh`, and fixed a dangling citation in `context-orchestration`. Six assertions back it; "nine core lenses" was retired, not aliased (`2026-11-06-suggestions.txt`).
- Built the retrieval-quality harness (`bench`) with an nDCG/token/embedding-identity regression gate and a committed baseline; fixed `bin/ainish-rag` exec'ing itself when its native binary was absent (silent recursion across WSL, Git Bash, Linux, unknown-OS). Gate exercised in all three states; 2 Windows-only failures proven pre-existing at pristine HEAD (`2026-11-06-suggestions.txt`).
- Fixed a silent Obsidian-vault downgrade: `rag.py generate_wiki` now refuses (SystemExit with reason + correct command) to overwrite pages tagged `ainish/wiki`; non-vault repos still generate normally. Made `--index` opt-in in both engines (`2026-11-12-generated-artifact-churn.md`).
- Fixed `wiki --index` disableability by removing clap `default_value_t = true` on that instance (`2026-11-12-clap-bool-default-true-flags.md`).
- Retired the end-of-turn spoken-suggestion/TTS channel (operator decision 2026-11-11): removed the 564-line root transcript, `src/help.sh` pack entry, README row/tree, `llms.txt` pack name, and pack-name references outside the distribution folder. Pack kept under `skills-to-distribute/`; content now ordinary `.agents/` context via `ainish-rag --context` (`2026-11-11-tts-channel-retired.md`).
- Removed the self-peering WSL entry (`windows-128gb`) from the federation registry (`2026-11-11-federation-gaps.md`).
- Contract/identity deploy landed: `--rules` copies the identity table into `.agents/bin/` and re-runs refresh it; contract files `uchg`-locked (`2026-11-20-16-contract-deploy-followups.md`).
- Contract-internals cleanup landed: `AGENTS.md` rewritten to what an agent must DO, 159 lines against the `<= 160` gate (`2026-11-20-17-contract-internals-followups.md` §2).
- Consolidation tooling built and exercised in test runs (both times restored); `context-consolidate` exists as a manual verb and `--cap` warns and names unsummarised records instead of failing (`2026-11-20-21-consolidation-followups.md` §1–§4).
- aiRPC canvas app browser-verified against tldraw 5.6.2: the v5 `ShapeUtil` change (`indicator()` → `getIndicatorPath(): Path2D`) surfaced as a runtime console error and was fixed against the installed `.d.ts`; version pinned in skill and module header (`2026-11-21-14-airpc-followups.md`, resolved 2026-11-21).
- Attribution table/test drift resolved: neither literal was canonical; the operator set the author form to `Nanoboozhoo embodied by: {agent harness}` and `scripts/test-pqc-dist.sh` now clears harness env markers and forces one known marker before asserting. Suite passes 441/441 (`2026-11-21-15-attribution-table-test-drift.md`, resolved 2026-11-22).
- Nothing is recorded as landed for the background-pass-clobber incident period (`2026-11-21-15-background-pass-clobber.md`).

## Unfinished

- **Un-summarized sources — recover before deleting anything else.** These 11 records were consolidated into DIGEST-suggestions-2026-11.md but their content never reached this draft (supplied excerpt cut mid-file). Nothing about their substance is asserted; each is recoverable from git history under its exact filename and summarized in the full text of DIGEST-suggestions-2026-11.md (its partial digests 2–4), itself in git:
  - `2026-11-12-large-context-retrieval-gap.md` — read from git.
  - `2026-11-12-nested-agents-secret-tree.md` — read from git.
  - `2026-11-12-rules-signing-anchor-mismatch.txt` — read from git.
  - `2026-11-13-probe-conflates-reachability-with-auth.md` — read from git.
  - `2026-11-14-federation-machine-link.txt` — read from git.
  - `2026-11-14-local-router-fallback-models-fixes.md` — read from git.
  - `2026-11-14-machine-watch-operations.txt` — read from git.
  - `2026-11-17-19-context-priming-master.md` — read from git.
  - `2026-11-19-15-context-agent-followups.md` — read from git.
  - `2026-11-19-16-retire-rag-followups.md` — read from git.
  - `2026-11-20-15-identity-trailer-followups.md` — read from git.
  Any future agent must pull these 11 from git and merge their open threads and lessons before deleting anything.
- Six RAG subcommands still carry the clap `default_value_t = true` defect (`orient.inject`, `orient.task_conditioned`, `cleanup.compact`, `cleanup.prune_worktrees`, `gate.verify`, `monitor.once` in `src/rag/src/main.rs`); only `orient.include_symbols` is genuinely configurable. `orient.inject` is highest-priority (agent-facing, `--inject false` inexpressible). Recommended fix: `ArgAction::Set` accepting `--flag true|false` (`2026-11-12-clap-bool-default-true-flags.md`).
- The vault/wiki generator is native-only; `rag.py`'s `generate_wiki` emits plain markdown and `bin/ainish-rag` routes plain invocations to Python. The reachable `wiki` cannot produce a vault; the fail-closed guard prevents damage but the split needs a decision (`2026-11-12-generated-artifact-churn.md`, `2026-11-12-rag-engine-authority-unstated.md`).
- `--machine-sync` two-lane divergence, verified live: WSL and Mac both committed atop `f104102`, `main` stayed diverged while peers reported `✓ synced`. Proposed fix in `_ms_pull` (merge peer ref when not an ancestor and tree clean; abort and report lanes on conflict; skip dirty trees with a reason). Until then check `git merge-base --is-ancestor <peer>/main HEAD` (`2026-11-11-federation-gaps.md`).
- Other federation/context gaps: `--capture`-after-UI-edit is habit, not enforced; `--context` prints the embed-provider banner on graph-only runs; Windows' embedding index is stale by construction; the router chain in `~/.config/local-router` silently diverges (`2026-11-11-federation-gaps.md`).
- Bench corpus too small (three saturated queries) — expand before Phase 2. Mirror the harness into the Rust engine or rebuild `ainish-rag.exe` (stale since 2026-10-31) (`2026-11-06-suggestions.txt`).
- A refused contract edit is invisible (`uchg` lock, byte-identical file, intent silently lost — already happened once). Open: (a) whether `ainish-coder --edit-rules` should be the only documented edit path, (b) whether a stale mtime-vs-intent check is possible, (c) at minimum the lock error should name the unlock command (`2026-11-20-16-contract-deploy-followups.md` §1).
- Deployed targets' identity scripts can go stale with nothing reporting it. Proposed: stamp the table with the source commit and have `--rules-doctor` compare (`2026-11-20-16-contract-deploy-followups.md` §2).
- Non-git targets get no identity hooks and the warning conflates "auto-sync not installed" with "identity hooks not installed". Proposed: split the warning (`2026-11-20-16-contract-deploy-followups.md` §3).
- The contract no longer names where the tooling lives. Unsettled: whether an agent ever needs to find the identity table from the contract alone — if so, name it in `.agents/llms.txt` (`2026-11-20-16-contract-deploy-followups.md` §4).
- `.agents/rag/` keeps the retired name for engine-written machine-local state. Proposed: rename to `.agents/state/` or `.agents/cache/` with a one-release read-both fallback; ~10 call sites plus the gitignore (`2026-11-20-17-contract-internals-followups.md` §1).
- The contract has one line of headroom (159 of 160). Unsettled: whether a rule can ever be added without something being cut; revisit 160 if that happens (`2026-11-20-17-contract-internals-followups.md` §2).
- `llms.txt` still describes `DecisionEngine`, `DriverEngine`, the decision chain, and context envelope internals. Unsettled: documentation (fine) or context (needs the contract's treatment) — depends on whether agents open it (`2026-11-20-17-contract-internals-followups.md` §3).
- Nothing verifies the contract is still true; recent rewrites were checked only by phrase greps. Proposed: a small assertion per named folder and command so drift fails the suite (`2026-11-20-17-contract-internals-followups.md` §4).
- The consolidation merge step fails more often than the chunks (merge returned nothing twice across three real runs; fallback digest reads as batches). Suspected cause is instruction shape, not size. Proposed: run the merge with the chunks' terse system prompt, measure over ~10 runs (`2026-11-20-21-consolidation-followups.md` §1).
- Consolidation is not on the `--context` path — a manual verb nothing triggers. Unsettled: whether it should be spawned by the same background pass as learning with its own interval, one decision with the autolearn throttle (not fired since 2026-11-19) (`2026-11-20-21-consolidation-followups.md` §2).
- Only `.agents/suggestions` had been consolidated before this period's runs; the other four folders — 136 files, ~150K tokens — were untouched at that record. Guidance: each folder's first run goes one at a time on `main` with the operator watching and each digest checked by eye (`2026-11-20-21-consolidation-followups.md` §3).
- `--cap` warns but does not enforce. Unsettled: whether "never more than 5" must become a gate — settled by whether a folder drifts over the cap and stays (`2026-11-20-21-consolidation-followups.md` §4).
- Partial-digest problem: a `tasks` period split into two chunks had one chunk fail review, yet a digest covering 1 of 16 records was written (`records_consolidated: 1`), leaving 13 originals and an over-cap folder. Options: (a) all-or-nothing per period, (b) one call per period (hermes measured able to take 40K), (c) name the chunk range in the digest filename. Settled by whether hermes can reliably take a whole period in one call (`2026-11-21-03-consolidation-gate-followups.md`, `2026-11-21-09-context-consolidation-jobs-followups.md`).
- Drafter prompt is under-specified: the reviewer caught real omissions (an escalated design question; a 24-key secrets-store incident) belonging under Unfinished. Settled by an explicit checklist pass ("list every unresolved item in the sources by filename before writing prose") — a prompt change (`2026-11-21-03-consolidation-gate-followups.md`).
- The consolidation pair does not self-improve: nothing writes a lesson back when the reviewer catches something twice, despite the operator's ask for recursive self-improvement. Settled by feeding `rejected/` back into the next draft for the same folder (`context-learn`) (`2026-11-21-03-consolidation-gate-followups.md`).
- The main checkout is on `feat/fleet-sync-reliability`, auto-created by machine-watch auto-commit machinery, not the operator; worktree operations keyed on `main` then behaved unexpectedly. Settled by checking whether `--auto-commit` uses `git checkout -b` and whether the watcher should refuse to act mid-task (`2026-11-21-03-consolidation-gate-followups.md`).
- The consolidation pass is best-effort: a detached child, so machine sleep loses the pass and folders stay over cap until the next `--context` call; the throttle records nothing because the attempt is only recorded on successful spawn. Settled by whether a durable queue is worth the machinery (`2026-11-21-09-context-consolidation-jobs-followups.md`).
- `.agents/jobs/` is invisible to retrieval (deliberately inert, but nothing indexes it). Settled by adding `("jobs", ".agents/jobs", True)` to `GRAPH_EXTRA_SOURCES` — a one-line change deliberately not made because the operator said no further configuration (`2026-11-21-09-context-consolidation-jobs-followups.md`).
- The watcher still runs a stale binary: plan item T7 (log the source commit at startup) is not implemented, and it runs under launchd from a checkout that may predate merged fixes. Settled by the operator restarting the watcher and confirming the new `watch.state` format (`started=`, `note=` keys) (`2026-11-21-09-context-consolidation-jobs-followups.md`).
- The aiRPC block manifest is still assembled by hand (SKILL.md §4), where a hand-rolled digest could silently diverge from the protocol. Settled when the operator asks for projection automation (`2026-11-21-14-airpc-followups.md`).
- aiRPC distribution is deliberately untouched (ships only in this repo's `.agents/skills/`). When the operator wants it in consumer repos, add to `skills-to-distribute/skills/` and decide bridge form then (`2026-11-21-14-airpc-followups.md`).
- Decide whether a digest's frontmatter should carry provenance (`written_by:` plus run id or pid/session) so a clobber is detectable after the fact (`2026-11-21-15-background-pass-clobber.md`).
- Decide whether `_digest_path` should refuse to overwrite an existing digest; sequence numbering prevents run collisions but does not extend to a same-index write (`2026-11-21-15-background-pass-clobber.md`).

## Insights

- Documentation degrades silently when the contract is refactored — a skill kept citing the removed nine lenses for weeks. The fix is a test, not a reminder (`2026-11-06-suggestions.txt`).
- A regression gate never seen to fail is not yet a gate — validate it in all three states first (`2026-11-06-suggestions.txt`).
- nDCG 2.131 out of range meant the metric definition was wrong, not the corpus — normalize against retrieved reality and assert the range (`2026-11-06-suggestions.txt`).
- In clap 4, a `bool` field with `long` is a presence flag; `default_value_t = true` yields a flag that can only ever be true. Only a `try_parse` round-trip asserting both polarities differ distinguishes "declared" from "usable" (`2026-11-12-clap-bool-default-true-flags.md`).
- Two engines answer `ainish-rag` but only the native one can produce a vault; the reachable default is Python, so any surface depending on wikilinks/frontmatter/tags is silently downgraded (`2026-11-12-generated-artifact-churn.md`).
- A launcher that execs itself recurses silently with no output and no exit (`2026-11-06-suggestions.txt`).
- A guest sharing its host's disk must not peer with its host (realpath equality); a guaranteed-failure peer teaches the operator to ignore the peer list (`2026-11-11-federation-gaps.md`).
- The AGENTS.md line gate is the binding constraint on documenting the context tool — worth a deliberate decision, not a silent trim (120 lines recorded in `2026-11-11-federation-gaps.md`; 159 of 160 after the rewrite in `2026-11-20-17-contract-internals-followups.md` §2).
- Move guidance into `.agents/` text, not generated transcripts — retrieval reaches an agent with no synthesis or root-transcript dependency (`2026-11-11-tts-channel-retired.md`).
- The `uchg` lock loses intent without any signal: a refused edit leaves the file byte-identical (`2026-11-20-16-contract-deploy-followups.md` §1).
- The contract deliberately traded away discoverability (read on every task; script paths are implementation detail) — why it no longer names where the identity table lives (`2026-11-20-16-contract-deploy-followups.md` §4).
- `.agents/rag/` is engine-internal state, not a retrieval system — but its name invites that misreading (`2026-11-20-17-contract-internals-followups.md` §1).
- `llms.txt` is returned by the context call, so its PRD-level engine detail doubles as prompt surface whether or not intended (`2026-11-20-17-contract-internals-followups.md` §3).
- Grep-for-phrases verification proves a phrase exists, not that behaviour matches the claim (`2026-11-20-17-contract-internals-followups.md` §4).
- The merge call is smaller than the chunk call yet fails more often — size is unlikely to be the failure driver; instruction shape probably is (`2026-11-20-21-consolidation-followups.md` §1).
- The partial-digest fallback preserves content but makes the result read like batches (`2026-11-20-21-consolidation-followups.md` §1).
- A consolidation digest replaces its source files and git is the only backup, so each folder's first production run deserves an operator watching (`2026-11-20-21-consolidation-followups.md` §3).
- Hermes can take a whole period in one call: 40K tokens in 66s measured — chunking may be unnecessary (`2026-11-21-09-context-consolidation-jobs-followups.md`).
- A digest written from a partially reviewed period understates it (`records_consolidated: 1` of 16) and leaves the folder over cap with a misleading digest (`2026-11-21-03-consolidation-gate-followups.md`, `2026-11-21-09-context-consolidation-jobs-followups.md`).
- The throttle is silent on failure: attempts are recorded only on successful spawn, so lost passes leave no trace (`2026-11-21-09-context-consolidation-jobs-followups.md`).
- tldraw 5.x changed the `ShapeUtil` contract (`indicator()` → `getIndicatorPath(): Path2D`); syntax checks alone don't catch API drift — the runtime console did (`2026-11-21-14-airpc-followups.md`).
- When a test and a data table disagree after a merge, neither side is necessarily canonical — the resolution here was a third, harness-independent author form (`2026-11-21-15-attribution-table-test-drift.md`).
- `_digest_path` produces a deterministic sequence name (`DIGEST-<folder>-01.md`) for a given folder state, so two runs over the same folder collide on the same path (`2026-11-21-15-background-pass-clobber.md`).
- `run_context_consolidate`'s lock covers only its own invocations; a manual write path has no lock against it (`2026-11-21-15-background-pass-clobber.md`).
- A clobber is invisible in the file and in `git status` — the only signal is a modified file whose `consolidated_at` stamp moved (`2026-11-21-15-background-pass-clobber.md`).

## Recurring

- Work is lost or degraded without a loud failure: the refused `uchg` edit leaves a byte-identical file (`2026-11-20-16-contract-deploy-followups.md` §1); stale identity tables on deployed targets are never reported (same file, §2); the merge call silently returns nothing and the fallback absorbs it (`2026-11-20-21-consolidation-followups.md` §1); `--cap` names the excess and fails nothing (same file, §4); the self-exec launcher recursed silently (`2026-11-06-suggestions.txt`); the Obsidian vault was silently overwritten (`2026-11-12-generated-artifact-churn.md`); `--machine-sync` reported `✓ synced` while `main` diverged (`2026-11-11-federation-gaps.md`); a bool flag silently could not be turned off (`2026-11-12-clap-bool-default-true-flags.md`); the throttle records lost passes only on successful spawn (`2026-11-21-09-context-consolidation-jobs-followups.md`); a background pass silently clobbered a manual digest (`2026-11-21-15-background-pass-clobber.md`). Shared lesson: a condition that matters should fail or report loudly — absence of an error is not proof of correctness.
- Untested wiring between components fails silently and survives: the retired nine-lens citation outlived weeks (`2026-11-06-suggestions.txt`); two-engine routing silently downgraded vault generation (`2026-11-12-generated-artifact-churn.md`); peer/ref ancestry was never asserted (`2026-11-11-federation-gaps.md`); tldraw API drift survived syntax checks (`2026-11-21-14-airpc-followups.md`). Shared lesson: assert polarity, ancestry, and state explicitly.
- Drift between a claim and reality goes unmeasured: contract claims verified only by phrase greps (`2026-11-20-17-contract-internals-followups.md` §4); deployed identity tables never compared against their installer (`2026-11-20-16-contract-deploy-followups.md` §2). Shared lesson: compare the state of the world against the claim, not the claim's wording.
- Consolidation output quality degrades quietly when a step fails or material is lost: the merge returning nothing absorbed by a fallback that reads as batches (`2026-11-20-21-consolidation-followups.md` §1); a digest written from a partially reviewed period understates it (`2026-11-21-03-consolidation-gate-followups.md`, `2026-11-21-09-context-consolidation-jobs-followups.md`); a background pass overwrote a manual digest invisibly (`2026-11-21-15-background-pass-clobber.md`); and this digest itself lost the contents of the 11 sources named first under Unfinished to an excerpt cut. Shared lesson: name exactly what is missing and where it is recoverable — never let it vanish silently.
- The partial-digest problem is recorded twice for the same `tasks` incident (`2026-11-21-03-consolidation-gate-followups.md`, `2026-11-21-09-context-consolidation-jobs-followups.md`) — one thread, not two.
- The machine-watch watcher causes trouble in two separate records: auto-creating a branch in the operator's checkout (`feat/fleet-sync-reliability`) and running a stale binary under launchd with no startup commit logging (`2026-11-21-03-consolidation-gate-followups.md`, `2026-11-21-09-context-consolidation-jobs-followups.md`).
- Reviewer catches of genuine omissions during consolidation drafting (a design question, a 24-key secrets-store incident) echo the under-specified drafter prompt — the checklist pass is the recurring proposed remedy (`2026-11-21-03-consolidation-gate-followups.md`).
