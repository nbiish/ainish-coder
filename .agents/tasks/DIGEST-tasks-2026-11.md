---
format: ainish/context-digest/v1
folder: tasks
period: 2026-11
records_consolidated: 26
consolidated_at: 2026-11-20T23:34:07.814327+00:00
sources:
  - 2026-11-05-rag-operator-utility-task.md
  - 2026-11-05-rules-skill-selection-task.md
  - 2026-11-06-pqc-crossplatform-task.md
  - 2026-11-06-rag-phase0-baseline-task.md
  - 2026-11-06-signing-failfast-task.md
  - 2026-11-08-wtf-integration-and-stale-refs-task.md
  - 2026-11-10-machine-sync-task.md
  - 2026-11-10-windows-main-sync-task.md
  - 2026-11-11-ainish-security-refresh.md
  - 2026-11-11-federation-graph-only-task.md
  - 2026-11-11-wsl-crossupdate-probe.md
  - 2026-11-12-absorb-security-first-agent-task.md
  - 2026-11-12-egm-context-prime.md
  - 2026-11-12-hour-stamped-coordination-task.md
  - 2026-11-12-mandatory-skill-deploy-task.md
  - 2026-11-13-00-driver-chain-direct.md
  - 2026-11-14-17-pi-agents-prime.md
  - 2026-11-14-21-machine-link-federation.md
  - 2026-11-14-22-branch-materialization-latest.md
  - 2026-11-14-23-machine-watch-daemon.md
  - 2026-11-18-14-single-command-context.md
  - 2026-11-18-15-comms-block-parsing.md
  - 2026-11-19-14-context-agent-correctness.md
  - 2026-11-19-15-retire-rag.md
  - 2026-11-20-09-identity-trailer-hook.md
  - 2026-11-20-10-contract-identity-deploy.md
---

# Digest — `.agents/tasks`, 2026-11

This digest replaces 26 record(s) from 2026-11. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Partial digests

The merge step did not complete, so these 6 partial digests are kept as written. Each covers a different batch of the records named above.

## Accomplished

- **Refocused `ainish-rag` as an operator utility, not agent intake** (`2026-11-05-rag-operator-utility-task.md`). Removed all agent-facing directives to run `route`/`orient` from `AGENTS.md`, `.agents/llms.txt`, and `context-orchestration/SKILL.md` (the "Route" phase became "Read"); the router-derived fields were dropped from the context-packet contract; a Scope paragraph was added to `llms.txt`. No CLI/flag/default changed. Verification: `rg` found no remaining directive, `AGENTS.md` byte-identical to the canonical copy (re-signed ML-DSA-65 k=1), `audit verify` 16/16, `test-pqc-dist.sh` 57/57, fleet 3/3 CURRENT. Cleanup: deleted merged branch `fix/rules-skill-selection` and worktree `ainish-coder-skills-select`; removed empty leftover `ainish-coder-egm-master-memory`; kept `ainish-coder-rules-smoke` enrolled.
- **Restored skill selection in `--rules`** (`2026-11-05-rules-skill-selection-task.md`). Fixed a silent zero-deploy caused by `b268b75` (removed interactive `_skills_toggle_ui`) plus `fdd8537` (flipped `skills_selection_default_on` to `off`). New `_rules_deploy_skills` runs three bounded paths — `always`/`never`/`auto` — governed by `skills_selection_tty_ok` and `skills_selection_ui_mode`; raw key read bounded by `AINISH_SKILLS_PROMPT_TIMEOUT` (default 120s). Added `--select-skills [DIR]` and `--skills-list [DIR] [--json]`. Verified `test-pqc-dist.sh` 51/51, pty smoke 21/21, unattended 4/4, fresh-install identity 7/7, `audit verify` 16/16, contract history 27 transitions.
- **Fixed PQC host-interop and the distribution gate** (`2026-11-06-pqc-crossplatform-task.md`). (1) `_decode_wsl_list()` now detects UTF-16-LE vs UTF-8 from byte shape (was unconditional UTF-16-LE → mojibake distro names → store invisible on Windows); tries both `\\wsl.localhost` and `\\wsl$`. Windows now reports `keyCount: 13`, `key_source: pqc:LOCALROUTER_OPENROUTER_API_KEY`. (2) Gate hermeticity fixed by pinning `PQC_SECRETS_DIR` + `USERPROFILE` (Python ignores `HOME` on Windows via `pathlib`). (3) Stamp fixture derived from `_ainish_stamp_alternative` with native-POSIX N/A branch. (4) Gate now fails closed without `uv` (was `exit 0` = false PASS); skip requires `AINISH_ALLOW_GATE_SKIP=1`. Result 73/73 on Windows, WSL, Linux; `unittest` 71 pass. **macOS not executed** (no host reachable; surfaces covered indirectly).
- **ainish-rag Phase 0 measurement harness + committed baseline** (`2026-11-06-rag-phase0-baseline-task.md`). `bench` now records nDCG@3 (graded relevance 2/1/0), per-query and avg chunk tokens, embedding identity, store row count, engine commit; `compare_to_baseline` gates on recall+nDCG at 90%, flags identity change as `incomparable`. Metric logic factored into testable functions. `.gitignore` changed to `.agents/rag/*` + `!.agents/rag/bench-baseline.json`. Committed baseline: Recall@3 1.000, nDCG@3 1.000, 920 chunk tokens/query, 1149ms latency, 3627 records, `api:openrouter:openai/text-embedding-3-small`, engine commit `fab34e1`. `unittest` 71 pass (18 new), `test-pqc-dist.sh` 73/73 on WSL.
- **Closed out signing fail-fast + smoke sandbox** (`2026-11-06-signing-failfast-task.md`). `_ainish_rules_require_signer` now preflights before writing any artifact, so a missing engine fails fast with build guidance (no manifest, no refresher, no hooks, no enrollment; existing manifest left intact). Cleared `D:\Code\ainish-coder\test` and removed its stale fleet enrollment. `test-pqc-dist.sh` 62/62 (5 new assertions), `audit verify` 16/16, fleet 2/2 CURRENT.

## Unfinished

- **Second corpus (`local-router`) not baselined** (`2026-11-06-rag-phase0-baseline-task.md`) — repo had 18 uncommitted paths (mid-flight skills refresh + modified deploy manifest/signature), blocking per non-negotiable #1. Needs a separate cleanup pass.
- **Rust engine not extended** (`2026-11-06-rag-phase0-baseline-task.md`) — `bin/ainish-rag.exe` is stale (built 2026-10-31; `src/rag/src/` at 2026-11-04; `--help` lacks `verify`). Launcher-driven Windows benchmarks report old metrics. Must be mirrored or rebuilt before trusting launcher benchmarks. Follow-up decisions named: mirror metrics into `src/rag/src/main.rs` or rebuild exe; retire the stale "EmbeddingGemma-2" claim at `rag.py:5` and `bin/ainish-rag:4`; fix two Windows-only gate failures.
- **Manifest signing still coupled to the compiled RAG binary** (`2026-11-06-signing-failfast-task.md`) — decoupling ML-DSA signing off the engine deliberately deferred (touches trust boundary; needs its own decision). `2026-11-05-rag-operator-utility-task.md` likewise scoped out moving signing off the compiled engine.

## Insights

- **The WSL hang was SIGTTIN, not a timeout bug** (`2026-11-05-rules-skill-selection-task.md`): the Windows `.exe` launches through `/init`, which reads inherited stdin; in a non-foreground process group that read *stops* the process, and a stopped child also stops the `timeout` watchdog so the 20s bound never fires. Detaching stdin on every engine invocation made timeouts enforceable (real-engine `--rules` went from hanging to 6–8s).
- **`--pqc-install` false-negatived on fresh installs** (`2026-11-05-rules-skill-selection-task.md`): it required `bundleExists`, but `keygen` only creates the ML-KEM-768 keypair — bundles appear on first secret pack. Success redefined as "launcher installed and a usable identity resolves"; existing stores masked the bug.
- **Directory-level `.gitignore` blocks negation** (`2026-11-06-rag-phase0-baseline-task.md`): `.agents/rag/` stopped git descending, so `!bench-baseline.json` was inert. Fix was `.agents/rag/*` + exception.
- **Router and PQC CLI disagreed on "key configured"** (`2026-11-06-pqc-crossplatform-task.md`): router's `getPqcConfigDirCandidates` scans `~/config`, `~/.config`, and Windows user dirs under WSL, so it reported `key_configured: true` while the CLI saw 0 keys. The 13 WSL keys are now discovered by both hosts; no re-packing needed unless a new key is added.
- **The saturated Phase 0 metric was uninformative** (`2026-11-06-rag-phase0-baseline-task.md`): binary Recall@3 all-pass = 100%, giving no room to show improvement; nDCG was added, and it initially exceeded 1.0 (2.131) until normalized against the ideal ordering of what was retrieved.

## Recurring

- **Host split between Windows and WSL PQC stores** recurs across `2026-11-06-pqc-crossplatform-task.md` (Windows saw 0 keys due to the decode bug; fixed) and `2026-11-06-rag-phase0-baseline-task.md` (baseline had to be recorded under WSL because the embedding key resolves only there). The canonical store is currently the WSL one, reached over interop.
- **The compiled `ainish-rag` engine as a trust/measurement boundary** appears three times: as a gitignored build artifact that half-deploys targets (`2026-11-06-signing-failfast-task.md`), as a stale binary that skews benchmarks (`2026-11-06-rag-phase0-baseline-task.md`), and as the thing signing is deliberately kept coupled to (`2026-11-05-rag-operator-utility-task.md`, `2026-11-06-signing-failfast-task.md`). Decoupling is the repeatedly-deferred decision.
- **Tests/gates that report success without running** recur as a class: the gate `exit 0` skip without `uv` (`2026-11-06-pqc-crossplatform-task.md`) and the `bench` self-exec hang that silently produced no output (`2026-11-06-rag-phase0-baseline-task.md`) — both fixed by failing closed.
- **Verification read-back rather than exit codes** is the shared discipline across all five: byte-identical contract copies, `audit verify` counts, fleet CURRENT counts, and per-host assertion totals are cited to prove effects landed.

---

## Accomplished

- **wtf task lane integrated + stale-ref sweep** (`2026-11-08-wtf-integration-and-stale-refs-task.md`, branch `chore/wtf-integration-and-stale-refs`, done): six `task_*` tools (`task_dispatch`, `task_claim`, `task_report`, `task_status`, `task_run`, `runner_probe`) with pull-based semantics, 15-min claim lease, `auto` runner preferring Orca over Herdr, port `7800` with no fallback. Added the pack to `.agents/skills/llms.txt`. Rebuilt README skills table/tree from the filesystem (removed 3 phantom packs `browser-harness`/`camofox-stack`/`skyvern` and `osa/`/`pi/`, added the 4 real ones). Marked the plan's Appendix B as historical rather than rewriting. Added a stale-ref detector gate proven against an injected fake pack (0→1→0). Verified: `test-pqc-dist.sh` 158/158, unittest 164 pass, tool catalog 23 declared/23 listed, `audit verify` after re-signing.
- **`--machine-sync`** (`2026-11-10-machine-sync-task.md`, branch `feat/machine-sync`, done): new `src/machine_sync.sh` (~600 lines) + `bin/ainish-coder --machine-sync`. Moves repos between capacity-named machines over SSH or local path, sends branches as `refs/remotes/<machine>/*`, snapshots dirty trees onto `refs/machine-sync/<machine>/<branch>` via throwaway `GIT_INDEX_FILE` (HEAD/index/worktree untouched). Registry: `mac-18gb=self`, `windows-128gb=windows-128gb:D:/Code`, `wsl-94gb=wsl-94gb:/mnt/d/Code`. `test-machine-sync.sh` 23/23; live mac↔Windows sync exit 0 with WIP snapshot landing both ways.
- **Rules checkout convergence** (`2026-11-10-windows-main-sync-task.md`, done): macOS `main` fast-forwarded `d045363..c5bf68e`, `origin/main` pushed to same. Transfer by `git bundle` over SSH then `merge --ff-only`. Verified HEAD = `c5bf68e` on all three surfaces, 389 tracked files both sides. Pre-sync baseline 150 pass/14 fail → synced 153 pass/14 fail (same 14 pre-existing PQC-environment failures), +3 assertions, no regression.
- **ainish-security refresh** (`2026-11-11-ainish-security-refresh.md`, done): four research tracks against primary sources, deltas mirrored byte-identically to `skills-to-distribute/skills/ainish-security/`. Corrected five *incorrect* (not merely stale) claims, added empirical MCP risk data (95 CVEs, 12 critical), MCP spec 2026-07-28, injection-defense consensus, agent workload identity, implementation-attack posture, signed≠trustworthy (TanStack/Shai-Hulud).
- **Federation + graph-only retrieval** (`2026-11-11-federation-graph-only-task.md`, done): `scripts/local-router-sync.sh` now derives a declarative `routes.boot.json`, passes it at boot, verifies the *route* not the port, refuses empty chains, gained `--capture`. `fallback-models.json` recaptured to 17 models. `src/rag/rag.py` graph-only by default (`AINISH_RAG_VECTOR_FALLBACK=1` opts in). `machine_sync.sh` gained `--auto-commit` and peer fast-forward-by-default. `ainish-rag`/`ainish-rag.cmd` route `context`/`secrets` to Python engine; binary renamed `ainish-rag.native.exe`. Verified 17 models on mac/Windows, `--context --retrieval-only` returns `mode wiki_graph`, `degraded: false` in seconds, WSL edit → commit `7609e64` → present on Mac. `test-machine-sync.sh` 26/26, `src/rag` tests 179/179.

## Unfinished

- **macOS vector retrieval** (`2026-11-10-machine-sync-task.md`): degrades to `vector_driver_unavailable` — no `lancedb` in the Python engine, no macOS binary. Fails closed honestly. Fix (add `lancedb` or a macOS build of `src/rag`) left as a deliberate decision. Largely superseded by graph-only default in the 11-11 task, but the `lancedb` gap itself is unaddressed.
- **Stale `bin\ainish-rag.exe` on Windows** (both 11-10 tasks): PATH resolves `.exe` before `.cmd`, so `ainish-rag --context` exits 2 there. Rebuild alone won't fix — the `PY_ONLY_SUBCOMMANDS` redirect lives on `feat/agents-context-prime`. The 11-11 task addressed launcher routing but did not confirm the stale `.exe` was removed.
- **Uncommitted Windows lane** (`2026-11-10-windows-main-sync-task.md`): `D:\Code\ainish-coder-context-prime` (`feat/agents-context-prime`, base `663da33`), 13 modified + 8 untracked, the only copy of the Rust redirect. Untouched; needs a commit before it can cross machines.
- **`D:\Code\ainish-coder\~`** (both 11-10 tasks): empty stray tree from an unexpanded `~`. Safe to delete with a literal path; left for operator confirmation.
- **`test-pqc-dist.sh` cleanup leak on macOS** (`2026-11-10-windows-main-sync-task.md`): trap can't remove its own `uchg` fixture, leaving an immutable `pqc-dist-test.*` dir each run. Needs `chflags -R nouchg` before `rm -rf`; trap fix is out of scope.
- **Windows vector-index warning** (`2026-11-11-federation-graph-only-task.md`): index built with API embeddings; harmless to graph-first, cleared by `ainish-rag index --rebuild`.
- **WSL cannot serve the chain** (`2026-11-11-federation-graph-only-task.md`): no `local-router` binary; stages but can't serve locally.
- **wtf docs unverified against binary** (`2026-11-08-wtf-integration-and-stale-refs-task.md`): `wtf` not installed, so the six tools, `7800` default, and Orca-before-Herdr are maintainer claims, not tested facts.

## Insights

- **A detector that only ever passes is indistinguishable from one that cannot fail** — the stale-ref gate was proved against an injected fake pack (0→1→0) before being trusted (`2026-11-08-...`).
- **Test can fail for the right reason vs the wrong reason**: the distinct-reviewer test failed on `main` because the PQC store dropped to 1 key (all tiers fail over to the router), not because rotation was broken. Fixed by asserting the chain property the code owns (`chain_steps`) rather than the credential-dependent answered model (`2026-11-08-...`).
- **Copying files can't express a git transfer** — deletions, renames, and machine-local build output (`ainish-rag.exe`, `.agents/rag`, signing keys) make `git bundle` the correct transport over `rsync` (`2026-11-10-windows-main-sync-task.md`).
- **A silently-accepted wrong config shape**: `local-router --config` accepted the persisted `routes` shape, then rewrote it from empty state — so the installer reported success while the chain was empty. Fix: declarative boot config + verify the route, not the port (`2026-11-11-federation-graph-only-task.md`).
- **Correct the record, don't rewrite it**: Appendix B kept as a historical note (it records *why* Phase 4 was scoped as new work); README rebuilt from filesystem rather than hand-patched (`2026-11-08-...`).
- **Distinguish incorrect from merely stale** in security claims (e.g. OpenSSL "native PQC" read as "validated"; ETDI having no spec standing) — wrong claims drive wrong design decisions (`2026-11-11-ainish-security-refresh.md`).
- **`git log main..<branch>` / diffstat / three-surface HEAD agreement** is the proof standard for merges; `exit 0` is a claim, re-read the target (`2026-11-10-windows-main-sync-task.md`).

## Recurring

- **Uncommitted work has no transport** — appears in both 11-10 records: the `feat/agents-context-prime` lane is the sole copy of the Rust redirect, sitting uncommitted on the Windows disk, which is the exact problem `--machine-sync`/`--auto-commit` was built to solve (`2026-11-10-machine-sync-task.md`, `2026-11-10-windows-main-sync-task.md`, `2026-11-11-federation-graph-only-task.md`).
- **14 pre-existing PQC-environment failures** recur across all three test runs (153/14 baseline; unchanged on WSL and macOS), consistently distinguished as pre-existing, not regressions.
- **Unexpanded `~` leaving a literal `~` directory** recurs in both 11-10 records (`D:\Code\ainish-coder\~`) and ties directly to the destructive-command contract in `AGENTS.md`.
- **Fail-closed-and-say-so** recurs: vector retrieval degradation, the machine-sync peer-missing exit 1, the route-vs-port verification, and "verify before you cite" in the security refresh all follow the same posture — never turn a failure into a silent success.

---

## Accomplished

**Mandatory skill deploy — "express mandatory once"** (`2026-11-12-mandatory-skill-deploy-task.md`): Consolidated the four drifted copies of the mandatory-pack list into a single `_skill_mandatory` predicate (`pqc-secrets`, `ainish-security`, `security-first-agent`). `_skill_channel_excluded` now hides via `_skill_mandatory` instead of naming packs; `_skills_mandatory_names` derives by enumerating the payload through the predicate; `_ainish_skill_mandatory` is a delegate that fails closed if the predicate is unloaded. `sync_ainish_skills` ships mandatory packs regardless of a recorded `off`. `--help` fixed from "20 packs / 17 listed" to all 19 packs with three marked mandatory. Verified: `test-pqc-dist.sh` PASS 240 (baseline 229), hermetic `--rules` deploys exactly the three mandatory packs, `--skills-list --json` shows them only under `mandatory`, `--skills-sync` deploys all three despite `false` entries, `--skills-verify` exits 1 with `MISSING MANDATORY: security-first-agent` when removed. `AGENTS.md` deliberately left unchanged (see Insights).

**Absorb `security-first-agent` into `AGENTS.md`, retire the pack** (`2026-11-12-absorb-security-first-agent.md`): Follow-up to the above — folded the skill's posture into a new `Security-first posture` section in `AGENTS.md` (order of operations, least-context subagents, no unattended authority, stop conditions, report requirements), then `git rm`'d the pack from both trees and removed it from `--rules`, both skills indexes, `llms.txt`, and `README.md`. Context call gained "the files win over the summary"; NN8 and *Close* prompt `.agents/suggestions/{date}-{slug}.txt`. Line gate raised 120→160 (AGENTS.md now 158 lines). Verified: PASS 239/239 (count reconciled: 4→3 packs = −3 per-pack checks, +2 new pins); hermetic `--rules` deploys exactly `ainish-security` + `pqc-secrets` with `security-first-agent` absent; `--skills-verify` and `--skills-sync` behave correctly.

**EGM context prime; retire the vector subsystem** (`2026-11-12-egm-context-prime.md`): Deleted the vector/embedding subsystem outright — `embed.rs`, `store.rs`, `ingest.rs` (1,359 lines) plus `lancedb`/`arrow` crates; eight subcommands (`serve`, `stop`, `index`, `query`, `rerank`, `bench`, `monitor`, `embed-provider`) and `service` retired in both engines. Each retired verb still parses and prints its replacement, then exits 1 (so `unrecognized subcommand` doesn't read as a typo). `retrieve_context` is now graph-only. Reviewer independence became a precondition: `distinct_reviewer_requested` inverted so separation is default, with `AINISH_RAG_ALLOW_SELF_REVIEW=1` / `--allow-self-review` as the recorded downgrade; `plan_reviewer_model` resolves the reviewer before spending calls and refuses when nothing distinct exists. Implemented full three-step Goldfish (comprehension → antagonistic → readiness). Added `--context --refresh-wiki`. Survivors preserved: `scrub_sensitive_content` + `is_ignored_path` → new `scrub.rs`, `read_or_init_privacy_budget` kept, `SearchHit` → local rerank contract in `decision.rs`, gate kept diff security checks (credential canary, Trojan Source), lost only embedding-anchored score. Verified: `test-pqc-dist.sh` 259→277 PASS; rag pytest 189→135 (54 retired); cargo test 59→55 (4 vector-only); same-model `--context` now **refused** with `degraded: true`; distinct models run all 3 goldfish steps.

**Hour-stamped coordination records** (`2026-11-12-hour-stamped-coordination-task.md`): Implemented the `{date}-{HH}-{slug}.md` naming convention (pre-2026-11-12 names stay valid). Fixed "newest wins" from name-sorted to mtime-sorted at `rag.py:5564`, `rag.py:5870`, `main.rs:3637-3640` — under grandfathering the name sort let `…-09-memory.md` beat `…-memory.txt`. Repaired plan discovery in three places (`rag.py:5897`, `plan_gate.sh:63`, `context-packet.sh:70`) that would have blinded the gate to the dropped `.plan.md` suffix. Swept eight unlisted hard-match surfaces. Repaired dead `_read_today_task_record` (`rag.py:7257`). Also fixed destructive wiki behavior: `generate_wiki` now refuses (rather than downgrades) `ainish/wiki`-tagged pages, `--index` made opt-in in both engines, vault title names project via `origin` not the worktree dir. Fixed `.gitignore` to `*.live.{txt,md}` (a `*-team.live.*`-only rule let `{date}-identity-guard.live.txt` be committed; one already on `main`).

`2026-11-11-wsl-crossupdate-probe.md` contained no body — only the header line `wsl-edit 2026-11-11T17:04:07Z`. Nothing to consolidate from it.

## Unfinished

- **Trust-anchor/seed rotation** — the deploy-time signature gate fails on this host for both `main` and worktrees: engine's local seed (signer `69e7233d…`) does not match the committed anchor (`d98405ea…`), so `--rules` exits 1 after deploying correct content. Pre-existing, surfaced in two tasks, left as an operator decision. Recorded to `.agents/suggestions/2026-11-12-rules-signing-anchor-mismatch.txt`. (Both `absorb-security-first-agent` and `hour-stamped-coordination` hit it; `mandatory-skill-deploy` declined to edit `AGENTS.md` partly because a re-signing pass would churn the audit chain.)
- **RAG engine authority unstated** — the wiki *writer* remains native-only (`src/rag/src/wiki.rs`); the reachable Python engine cannot generate a vault it doesn't already have. Recorded to `.agents/suggestions/2026-11-12-rag-engine-authority-unstated.md`. (`hour-stamped-coordination`)
- **Seven more clap bool flags** share the `#[arg(long, default_value_t = true)]` defect (flag can only ever be true; `--index false` fails). Recorded to `.agents/suggestions/2026-11-12-clap-bool-default-true-flags.md`. (`hour-stamped-coordination`)
- **`AGENTS.md` contract row for `security-first-agent`** — deferred so it lands with the anchor rotation in one re-signing pass (the pack is currently mandatory by predicate + payload index, not by a contract row). (`mandatory-skill-deploy`)

## Insights

- **A skill is progressive disclosure; a contract is not.** The whole reason `security-first-agent` was absorbed into `AGENTS.md` and then deleted: a skill an agent never triggers is never read, so security posture belongs in the one file every session reads whole. (`absorb-security-first-agent`)
- **"Mandatory" duplicated four ways had already silently drifted.** The fourth copy (`_skills_mandatory_names`) said only `pqc-secrets`, so the CLI's own "no optional packs selected" hint compared against a wrong set. Single-source predicates prevent a whole class of drift. (`mandatory-skill-deploy`)
- **The plan edited the wrong engine.** `bin/ainish-rag:69` hard-codes `PY_ONLY_SUBCOMMANDS=" context secrets "` and no native binary ships in `bin/`, so `rag.py` serves every `context` call — the plan's Rust-only scope would have changed nothing reachable. The reachable wiki generator (Python) writes plain markdown and was silently destroying Obsidian frontmatter/wikilinks while reporting success (measured: 11 wikilinks → 0). (`hour-stamped-coordination`)
- **Name-sort "newest wins" is false exactly on grandfathering days**, when old- and new-scheme files coexist and collate wrong. mtime is the correct invariant. (`hour-stamped-coordination`)
- **Self-review by default was the norm and is the bug.** The session's own context call reported `elephant=mimo-v2.6-pro | goldfish=mimo-v2.6-pro` — drafter reviewing itself. EGM requires a distinct reviewer and fails the review otherwise; the code now matches. Expected first failure: on a single-provider host, review is refused entirely rather than downgraded — intentional, but reads as a regression to anyone expecting a goldfish section every time. The `pair:` line and `reviewer_isolation` provenance distinguish "refused on purpose" from failure. (`egm-context-prime`)
- **Editing `AGENTS.md` is not free**: the deploy path re-signs `.agents/canonical/*` and appends to `.agents/audit/contract-history.jsonl`; a test deploy churned four canonical files + one chain entry signed by the non-anchor local key, so the edit was reverted. Contract edits and anchor rotation should land together. (`mandatory-skill-deploy`)

## Recurring

- **The `d98405ea…` anchor vs `69e7233d…` local seed signing mismatch** appears in three of the five records (`absorb-security-first-agent`, `hour-stamped-coordination`, `mandatory-skill-deploy`) as a pre-existing baseline failure that blocks clean `--rules` verification and deters `AGENTS.md` edits. The single highest-leverage unresolved item this period.
- **"Express it once, fail closed on divergence"** — the mandatory-skill consolidation and the EGM reviewer-independence inversion are the same lesson: a duplicated default drifts (mandatory list) or defaults to the wrong behavior (self-review); both were fixed by making the correct behavior the enforced default and refusing/downgrading loudly rather than silently.
- **Verify by reading back, and record the baseline** — every task reconciled test counts against a stated baseline (229/240, 259/277, 189→135, 59→55) and ran hermetic probes, explicitly separating pre-existing failures from task deltas.

---

## Accomplished

**`fix/driver-chain-direct`** (`2026-11-13-00-driver-chain-direct.md`) — `DRIVER_CHAIN` rewritten to exactly the operator's four steps: `local-router/fallback-models` → `127.0.0.1:11434`; `zai` `glm-5.3-flash` → `https://api.z.ai/api/coding/paas/v4`; `xiaomi-mimo` `mimo-v2.6-pro` → `https://token-plan-sgp.xiaomimimo.com/v1`; `openrouter` `deepseek/deepseek-v4.1-flash-1017` → `https://openrouter.ai/api/v1`. The previous 86-line chain (four router routes + six direct fallbacks across Nous Portal, Nebius, ZenMux, Z.AI, Xiaomi) was deleted. Steps 2-4 were router *routes* carrying `transport: "local-router"`, so one dead vendor upstream failed all three against the same route. `DRIVER_TIERS` pruned to the four usable transports plus the `local-model` floor. `DRIVER_KEY_NAMES` already listed `LOCALROUTER_{ZAI,XIAOMI_MIMO,OPENROUTER}_API_KEY`, matching the PQC vault — no key rename needed. Three assertions in `scripts/test-pqc-dist.sh` pin `transport`↔`id` pairing. Gates: pytest 135→137; `test-pqc-dist.sh` 277→285 PASS. Live `chat()` returned `OK` through `local-router/fallback-models` with an empty `attempts` list.

**`feat/pi-agents-prime`** (`2026-11-14-17-pi-agents-prime.md`) — both elephant and goldfish now run as `pi --print --no-session --no-tools --mode json` agent turns via `pi_agent_call`, with long role briefs (authority, hard rules, word caps), real file attachments (`_attach_paths_from_hits`, up to 6 paths, guarded against path escape / 512KB `PI_MAX_ATTACH_BYTES` / oversize / ignored / duplicates) plus the inline excerpt as floor. `PI_MODEL_IDS` translates engine transports to pi's provider-qualified ids. Thinking level became the cost dial (elephant `off`, goldfish `low`, `AINISH_RAG_PI_THINKING` overrides). Reviewer independence is now checked up front against the models actually handed to the roles. The elephant note is passed whole (the old 3,000-char cut was caught by a live reviewer and wasted a finding). Gates: pytest 137→145; `test-pqc-dist.sh` 285→296; live `--context` 41.6s→22.4s; live reviewer 1-of-3 truncated → 3-of-3 with real content. The thinking-leak test was proven by deliberately making `_pi_extract_text` accept `thinking` blocks.

**`feat/machine-link-federation`** (`2026-11-14-21-machine-link-federation.md`) — new `src/machine_link.sh` gives `--machine-link`: a `links.txt` peer registry with CRUD plus a `post-commit`/`post-merge` hook (send-only, `--linked-only`, env-guarded, idempotent, fully removed by `--remove`). `src/machine_sync.sh`: `_ms_remote` fixed for local peers, every peer probe guarded so `set -e` cannot abort on a missing ref, added `--quiet`/`--all`/`--linked-only`, peer path now resolves `--peer-path` → link → guess and reports which. Docs corrected in `src/help.sh`, `README.md`, `llms.txt` — including `--ff-peers` default (on, not "off"). New test sections 10–14. Gates: `test-machine-sync.sh` 20 passed/6 failed → **48 passed/0 failed**; `test-pqc-dist.sh` **302 passed/0 failed**. Live: Windows peer `--dry-run` went exit 1 + truncated header → exit 0 with `path from link` and a real forecast; push delivered all Mac branches plus the WIP snapshot, confirmed peer-side with `for-each-ref`; a hermetic run proved a commit propagates with no command typed (peer `main` advanced to the commit SHA).

## Unfinished

**`feat/branch-materialization-latest`** (`2026-11-14-22-branch-materialization-latest.md`, status *implementing*) — make every branch a local branch on both machines and report which machine holds the newest commit per branch. Motivation: `--machine-sync` only ever delivered `refs/remotes/<machine>/*`, so the Mac held 6 local branches while Windows held only `main`; `--status` is documented no-network, so nothing answered the question that decides where to work.

**`feat/machine-watch-daemon`** (`2026-11-14-23-machine-watch-daemon.md`, status *implementing*) — `--machine-link --watch`, a per-user launchd/systemd poll loop (change detect → debounce → existing `--machine-sync --both --branches --auto-commit --linked-only --quiet`). New `src/machine_watch.sh` and `scripts/test-machine-watch.sh`. Needed because hooks fire on commit while the real workflow is edit/save/switch machines.

**Left deliberately undone:**
- Converging `goal-first-trillion` onto `origin/main` (`...21-machine-link-federation.md`): the three copies share no ancestor and this checkout has 24 uncommitted paths. Mac tips preserved as `preserve/mac-3c87fac` and `preserve/mac-dirty-tree` and delivered to the peer; the merge rewrites a working branch, so it is the operator's call.
- Windows `machines.txt` still points `mac-18gb` at `/Users/nbiish/code`; fixing another machine's registry is an operator action, `--machine-link` there is the per-repo fix.
- Steps 2–4 of the driver chain cannot answer on this host: the PQC vault is locked, so `pqc-secrets export --json` prompts and `_pqc_export()` returns 0 entries, `resolve_driver_key` returns `None` for all three. Proving the three direct providers end-to-end needs `pqc-secrets unlock`.
- `pi auth check --model xiaomi/mimo-v2.6-pro` returns `not_ready`, so the xiaomi reviewer path is unexercisable here. `zai` gave the best reviewer (2.0s, strongest review) but is a paid direct call; without a zai key the reviewer falls to a chain containing `local-router` — slower, works.

## Insights

- **Router routes are a single point of failure.** Sending a vendor's model id to `127.0.0.1:11434` with `transport: "local-router"` means the router picks the vendor; a live router with one dead upstream fails every such step identically while the operator's real fallbacks sit queued behind vendors nobody requested (`...00-driver-chain-direct.md`). Pinning `transport` against each `id` in tests is what keeps this from regressing silently — the model strings alone would still all be present.
- **Reachability ≠ authorization.** `ainish-rag secrets` showed `openrouter` as `up` with no key, because its `/models` catalogue is public; the probe passed while the chat path would 401. Pre-existing, recorded in `.agents/suggestions/2026-11-13-probe-conflates-reachability-with-auth.md`.
- **A context call is a latency budget, and the reviewer was most of it.** Of a 41.6s `--context` call, retrieval was 19ms and orientation 47ms, elephant 6.9s, goldfish **33.5s**. Payloads were tiny (elephant prompt 1,551 chars, goldfish 2,004), so size was never the issue: three reviewer calls each burned ~15s and then died with `finish_reason=length, max_tokens=672`. The time budget had been raised for reviews; the token budget (`max(600, goldfish_cap*4)`, goldfish_cap = 14% of 1,200) never was, and a reasoning model spends 672 tokens on reasoning alone (`...17-pi-agents-prime.md`).
- **Reviewer rotation fought the locked vault.** Separation correctly rotates goldfish off the drafter's transport, but with the vault locked `local-router` is the only keyless step — and that is the one it rotated away from.
- **Thinking level is the dominant cost lever.** One-word reply: 6,904 input tokens at `--thinking high`, 56 at `off`. Hence elephant `off`, goldfish `low`.
- **Bare model ids are ambiguous to `pi`** — `glm-5.3-flash` resolves across five providers and `pi` refuses rather than guessing (observed live), hence `PI_MODEL_IDS`.
- **`pi` specifics verified before designing against it** (1.5.2): `--print --no-session --mode json`, `@file` attachments (it picked the relevant of two files and dismissed the irrelevant one), `--append-system-prompt`, router `ready`, no session state written, and typed content blocks (`thinking` + `text`) that must be separated on extraction.
- **Peer CLI versions constrain the transport.** Windows runs `ainish-coder` at `1bd8865`, predating `--machine-link`, so peer-side mutation must be plain `git -C … branch …` over ssh, never the peer's own CLI (`...22-...`).
- **History incompatibility blocks both auto-merge and clean materialisation.** Mac `main` `e4f845d` and Windows `main` `555b46e` share no common ancestor, so branch materialisation is strictly additive: create when the name is absent, and when it exists but differs, refuse and report both tips. Overwriting to make a report look clean would destroy one machine's history.
- **Peer paths cannot be guessed** — `<peer-root>/<repo-name>` was wrong whenever a repo lives under different trees (the Mac repo resolves to `/Users/nbiish/code/...` from Windows but sits under a removable-volume code root here). Links carry intent that ref transport cannot.
- **A save is not a commit**, so hook-driven sync leaves the actual edit/save/switch-machines workflow untransported; and with no `fswatch`/`inotifywait` on this host, "instant" watch is a ~2s poll plus debounce, not a kernel event.

## Recurring

- **The PQC vault being locked on this host** degrades verification twice: driver-chain steps 2–4 cannot answer, and goldfish rotates onto `local-router`. In both records the fallback is correct fail-closed behaviour, not a defect — but it means the strong path is never proven here, only the weak one.
- **The operator's stated endpoint list must be the chain itself, not a chain plus extras.** Both `...00-driver-chain-direct.md` and `...17-pi-agents-prime.md` involved removing layers nobody asked for (six unrequested vendors; the reviewer's 3,000-char truncation) and letting a stated requirement (direct calls; fresh-reader independence) be structural rather than conventional.
- **Budgets sized from the wrong quantity.** Time raised, tokens not (`...17-...`); reachability probed, authorization not (`...13-...`). Each produced a green signal over a broken path.
- **Peer state is an operator decision, not an agent decision**, and the agents consistently stopped at that line: the `goal-first-trillion` merge, Windows `machines.txt`, overwriting a divergent branch, and (prospectively) divergence in the watch daemon are all reported rather than resolved.
- **Every change shipped with a test count that moved in the right direction and a named gap**: 135→137→145 pytest, 277→285→296→302 `test-pqc-dist.sh`, 20/6→48/0 `test-machine-sync.sh`, each record closing with an explicit "not verified, and why".
- **`main` was never worked on.** All five records name a branch, a plan under `.agents/plans/`, and a worktree (`ainish-coder-chain`, `ainish-coder-pi`); two tasks are mid-flight and self-report as `implementing` rather than claiming done.

---

## Accomplished

**Single-command context + rules in the prime** (`2026-11-18-14-single-command-context.md`). `ainish-rag --context` now returns the rules (digest in `orientation`, which is never skipped and costs no model call) plus the prime. Learning is spawned detached *after* the prime is assembled (synchronous answer, async improvement), throttled by 6h **and** ≥1 new commit. `AGENTS.md` had been absent from `_graph_sources`; scope covered `src/rag/rag.py`, `context_harness.py`, `AGENTS.md`, `scripts/test-pqc-dist.sh`, research doc. Merged at `8321849`; 342 assertions pass.

**COMMS block parsing** (`2026-11-18-15-comms-block-parsing.md`). Parser split only on `### `, so `---`-fenced ledgers printed `- today's COMMS, last entry: ---`. Now accepts both delimiter styles (historical ledgers are append-only). Scope: `src/rag/rag.py`, `scripts/test-pqc-dist.sh`. Done.

**Context-agent correctness** (`2026-11-19-14-context-agent-correctness.md`). Made `ainish-coder --context "<input>"` the single entry point, backed by a real index. Key landings:
- Artifact cap: `BASE_PROFILE` capped at 2 vs engine's "unlimited" → only 60/167 files indexed; now `0`=all via `base_settings()`, **164 files / 411 nodes**.
- Edges bounded `GRAPH_MAX_EDGES_PER_NODE = 24` (was 42,216 edges / 102 per node → **4,220 / 10**).
- `KIND_INTENT` boosts the layer a task names; rules rank 1-2; a layer-naming task forces retrieval (no `skip_retrieval`).
- Acceptance referent = task record at `status: done`; `--task-record`, `--outcome ok|fail|unknown` added, `unknown` refuses.
- Seeded generation 0 (`history/`, `EXPERIENCE.md`, `prime-profile.json` never existed); rollback moved profile + `.skills` snapshot; `_coverage_loss_guard` refuses narrowing; `--refresh-wiki` accepts Python-generated frontmatter (SIGNED ledger still refuses).
- One skill surface: `.agents/context-harness/skills/`. Three provenance states (`distinct-model`, `fresh-context`=PROVISIONAL, `refused`). Weights applied per kind (presence, not truthiness). `--rag` fixed via readonly `AINISH_BIN_DIR`. Learned-state verbs resolve worktree root; shared caches keep canonical root.
- Verified: 380 assertions (354 baseline), 160-line AGENTS.md, corpus probe top-5 4/11 → **10/11**.

**Retire RAG + embedding era** (`2026-11-19-15-retire-rag.md`). `src/rag/` → `src/context/engine.py`; deleted ~7k-line Rust crate (13,733 lines). `ainish-context` launcher; `ainish-rag` is a deprecated forwarding shim. `--embed-config` removed (exits 1); 9 retired subcommands intercepted pre-parse; completions generated from live verb table. Signing moved to ML-DSA-65 in Python (`cryptography`, 32-byte seed). Bugs found: **`audit verify` was fail-open** (checked `.sig` existence only, not digest — a 2026-10-29 envelope named different bytes); `audit sign` wrote `.json.sig` no reader read and returned success; `audit lock --update` from a worktree wrote MAIN's manifest; Python keygen wrote `sha256(priv)` as a public key; `--rules` signing was already broken by the binary's removal. Verified: 387 assertions (382 baseline), `audit contract --verify-history` 66 transitions ML-DSA-65 valid, tampering → digest MISMATCH, `git grep ainish-rag` shows only shims/schema strings/receipts.

**Identity trailer hook** (`2026-11-20-09-identity-trailer-hook.md`). `commit-msg` strips harness trailers *before* the object exists (no amend/re-sign). Single table `scripts/harness-attribution.txt` read by hook+guard+rewrite; `Signed-off-by:` preserved. `setup-hooks.sh` installs both hooks idempotently (one checkout had 12 duplicate blocks); hooks go to `--git-common-dir` (worktrees never read `--git-dir`/hooks); deploy resolves `git rev-parse --git-path hooks`. **62 unpushed commits** carried a trailer → 0, tree hash unchanged `a1e6f70e3ef6`; **20** were rewritten (operator decision), pushed history left intact. Verified: 397 assertions (387 baseline), live `Co-authored-by: Cursor` commit arrived stripped.

## Unfinished

- `2026-11-18-14`: "Move these changes into `feat/single-command-context`, re-run the suite there, merge oldest-first" was the next action; the record's status says done/merged at `8321849`, so this was completed, but the deliberate-deviation note (work begun on `main` before the worktree) is a standing contract violation to be aware of.
- `2026-11-18-15` and `2026-11-20-09` leave only the generic "commit, merge, remove the worktree" step; no substantive work is recorded as incomplete.

## Insights

- Putting the rules digest in `orientation` (not `retrieval`) was the fix for routing that can skip retrieval — orientation is never skipped and needs no model call. (`2026-11-18-14`)
- Detaching improvement *after* the prime resolves the "answer must be synchronous" objection instead of ignoring it; the throttle needs both 6h and ≥1 new commit because an unguarded spawn burns a model session and the outcome signal needs commits to read. (`2026-11-18-14`)
- Two COMMS delimiter styles coexist; historical ledgers are append-only, so parse both rather than migrate. A wrong-but-plausible line (`last entry: ---`) is worse than omitting the line. (`2026-11-18-15`)
- Engine constants and `BASE_PROFILE` diverged silently (cap 2 vs "unlimited"); deriving one from the other prevents recurrence. (`2026-11-19-14`)
- A gate whose referent can never be satisfied is not a control: `status: done` is accepted even when merge shas can't be corroborated (all four historical records name shas gone after cross-machine rebases), recorded as `corroborated: false`. (`2026-11-19-14`)
- A generation is profile **+** `.skills` snapshot; rollback that restores only the profile leaves a newer generation's skill staged. (`2026-11-19-14`)
- Audit verbs must resolve the **worktree** root (receipts describe this checkout); shared caches resolve the **canonical** root. (`2026-11-19-14`, `2026-11-19-15`)
- Fail-open verification is the dangerous class: `audit verify` reporting PASS on `.sig` existence, and `audit lock --update` printing "synchronized & signed" regardless, both looked correct. Digest comparison, not existence, is the check. (`2026-11-19-15`)
- In a worktree `--git-dir` is `.git/worktrees/<name>`; hooks there are never run. Use `--git-common-dir` / `git rev-parse --git-path hooks`. (`2026-11-20-09`)
- A guard that exits early on the "author already correct" condition is unreachable for the case it exists to catch. (`2026-11-20-09`)
- Strip the offending trailer rather than rewriting it to `embodied by: X`: the phrasing is not a git trailer (`interpret-trailers --parse` returns nothing) and the author field already records the harness. (`2026-11-20-09`)

## Recurring

- **Worktree-path defects** appear in three records: `context-seed` writing MAIN's checkout (`2026-11-19-14`), `audit lock --update` writing MAIN's manifest (`2026-11-19-15`), and hooks installed to a path git never reads in a worktree, both in `setup-hooks.sh` and deploy (`2026-11-20-09`). The fix is the same each time: resolve the worktree root for per-checkout artifacts, the common/canonical root for shared caches.
- **Silent no-ops masquerading as success**: `audit sign` writing the wrong filename and returning 0, `audit lock --update` printing success regardless, `audit verify` passing on existence, `weights` reported but never read (`0.0` swallowed by `or`). Verification-by-readback beats exit codes, repeatedly.
- **Config/constant divergence**: engine "unlimited" vs `BASE_PROFILE` cap 2; caps and skill ceilings (`MAX_LIVE_SKILLS` 3→8). Numbers that should agree are stated in two places.
- **The single entry point** `ainish-coder --context` (with `ainish-rag` deprecated) is the throughline of `2026-11-18-14`, `2026-11-19-14`, and `2026-11-19-15`; each task moves closer to one self-improving context surface.
- **Contract-conformance is the standing constraint**: AGENTS.md stays 160 lines and every non-negotiable greps present across `2026-11-19-14`, `2026-11-19-15`, `2026-11-20-09`; the identity-hook task is rule 4 enforced in code; the 2026-11-18-14 deviation is recorded, not hidden.

---

## Accomplished

Task `2026-11-20-10-contract-identity-deploy` landed on branch `feat/contract-identity-deploy`, merged, status done, with plan at `.agents/plans/2026-11-20-10-contract-identity-deploy.md`. Four changes shipped (`2026-11-20-10-contract-identity-deploy.md`):

- `AGENTS.md` and `.agents/canonical/AGENTS.md` rule 4 rewritten to state the authorship rule and the `Nanoboozhoo - embodied by {agent harness}` form instead of naming enforcement scripts. File is 160 lines.
- `src/deploy_rules_sync.sh` now copies the identity table, stripper and guard into `<target>/.agents/bin/` and installs `commit-msg` + `post-commit` blocks there, with relative `.agents/bin/…` paths so target hooks reference no absolute path into the installing checkout.
- `bin/ainish-coder`: removed the call to `deploy_embed_provider_detect` (deleted 2026-11-19), so `--rules` no longer emits `command not found`.
- `scripts/test-pqc-dist.sh`: replaced the assertion pinning the contract to a script filename with one asserting the rule is present and no enforcement script is named.

Verification recorded: 407 assertions pass (397 baseline, 10 new), including a behavioural test that commits into a deployed scratch repo and asserts the trailer was stripped; `ainish-context audit contract --verify-history` verified 66 transitions after re-signing; contract re-locked (`operation not permitted` on write).

## Unfinished

Nothing left open. One deliberate non-goal is recorded: the contract no longer names where the enforcement tooling lives, so an agent cannot discover the harness table from the contract alone. If that discovery is ever needed, it belongs in `.agents/llms.txt` — not created as part of this task.

## Insights

- Both contract files are `uchg` at mode 444. An operator's edit to them fails silently at the tool level with `operation not permitted`, leaving the file byte-identical to HEAD — the earlier edit was never applied and this looked like a no-op change. Re-signing/re-locking is required after any contract edit.
- `install_root_rules_sync_hook` writes to `${REPO_DIR}`, the source checkout, and takes no target argument. That is why `--rules` deployed no identity hooks: every repo deployed before this fix generated commits carrying harness trailers, independent of the machine that deployed them.
- `scripts/test-pqc-dist.sh` is the effective regression net for the deployment path (407 assertions); the identity behaviour is covered by an actual commit into a scratch repo rather than a static check, which is what caught the missing-hook bug class.
- Assertion design matters: an assertion naming an implementation detail (a script filename) becomes a false failure when the contract is intentionally decoupled from tooling; assert the rule's presence and the absence of implementation detail instead.

## Recurring

One record only in this period, so no recurrence can be established from it. The closest cross-cutting lesson: enforcement belongs in tooling and hooks, not in prose — the contract states the rule, and the deployed repo's own hooks strip attribution, so correctness does not depend on which machine performed the deployment.
