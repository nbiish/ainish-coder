---
format: ainish/context-digest/v1
folder: tasks
period: 2026-11
records_consolidated: 16
consolidated_at: 2026-11-21T00:02:58.616672+00:00
sources:
  - 2026-11-13-00-driver-chain-direct.md
  - 2026-11-14-17-pi-agents-prime.md
  - 2026-11-14-21-machine-link-federation.md
  - 2026-11-14-22-branch-materialization-latest.md
  - 2026-11-14-23-machine-watch-daemon.md
  - 2026-11-15-09-watch-suggestions.md
  - 2026-11-17-13-federation-discoverability.md
  - 2026-11-17-19-context-priming-master.md
  - 2026-11-18-10-wiki-pseudo-skills.md
  - 2026-11-18-14-context-harness-state.md
  - 2026-11-18-14-single-command-context.md
  - 2026-11-18-15-comms-block-parsing.md
  - 2026-11-19-14-context-agent-correctness.md
  - 2026-11-19-15-retire-rag.md
  - 2026-11-20-09-identity-trailer-hook.md
  - 2026-11-20-10-contract-identity-deploy.md
---

# Digest — `.agents/tasks`, 2026-11

This digest replaces 16 record(s) from 2026-11. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Partial digests

The merge step did not complete, so these 4 partial digests are kept as written. Each covers a different batch of the records named above.

## Accomplished

- **Driver chain rebuilt to the operator's exact four steps** (`2026-11-13-00-driver-chain-direct.md`, branch `fix/driver-chain-direct`, status done). `DRIVER_CHAIN` now sends `local-router/fallback-models` to `127.0.0.1:11434` → `zai glm-5.3-flash` to `api.z.ai/api/coding/paas/v4` → `xiaomi-mimo mimo-v2.6-pro` to `token-plan-sgp.xiaomimimo.com/v1` → `openrouter deepseek/deepseek-v4.1-flash-1017` to `openrouter.ai/api/v1`. The old 86-line chain (four router routes + six direct fallbacks across Nous/Nebius/ZenMux/Z.AI/Xiaomi) was deleted; `DRIVER_TIERS` pruned; `llms.txt` and `scripts/test-pqc-dist.sh` updated with three assertions pinning transport↔id. Verification: `pytest src/rag/tests` 135→137, `test-pqc-dist.sh` 277→285 PASS, live `chat()` step 1 returned `OK` via `local-router/fallback-models`.
- **`pi` is now the runtime for elephant + goldfish** (`2026-11-14-17-pi-agents-prime.md`, branch `feat/pi-agents-prime`, status done). `pi_agent_call` runs `pi --print --no-session --no-tools --mode json --thinking <level> ...` with long role briefs, real file attachments (up to 6 paths via `_attach_paths_from_hits`, escape/oversize/dedupe guarded), and `PI_MODEL_IDS` translating transports to provider-qualified ids. Fixed three root causes of a 41.6s call: token budget (`max(600, cap*4)`≈672) too small for a reasoning model, reviewer rotated off the only keyless transport, and thin ~2KB inline prompts. Verification: `pytest` 137→145, `test-pqc-dist.sh` 285→296 PASS, live `--context` 41.6s→22.4s, reviewer 2/3→3/3 steps. Independence, thinking-leak, path-escape, oversize, dedupe, timeout, missing-binary each have a test.
- **`--machine-link` persistent federation** (`2026-11-14-21-machine-link-federation.md`, branch `feat/machine-link-federation`, status done except convergence). New `src/machine_link.sh`: `links.txt` registry CRUD + `post-commit`/`post-merge` hook, send-only, `--linked-only`, env-guarded, idempotent. Fixed `_ms_remote` for local peers, guarded probes under `set -e`, peer path resolves `--peer-path` → link → guess. Verification: `test-machine-sync.sh` 20 passed/6 failed → **48 passed/0 failed**; `test-pqc-dist.sh` 302 passed/0 failed; hermetic proof a commit propagates with no command (peer `main` advanced to the commit SHA).

## Unfinished

- **Branch materialization** (`2026-11-14-22-branch-materialization-latest.md`, status implementing). Sync delivered branches only as `refs/remotes/<machine>/*`, not checkout-able; the design is strictly additive (create when absent, refuse-and-report when tips differ) because Mac `main` `e4f845d` and Windows `main` `555b46e` share no ancestor.
- **`--machine-link --watch` daemon** (`2026-11-14-23-machine-watch-daemon.md`, status implementing). New `src/machine_watch.sh`; a per-user launchd/systemd poll loop (~2s poll + debounce, since no fswatch/inotify on host) invoking the proven `--machine-sync --both --branches --auto-commit --linked-only --quiet`.
- **Convergence decisions left to the operator** (`2026-11-14-21`): merging `goal-first-trillion` onto `origin/main` (three copies share no ancestor; this checkout has 24 uncommitted paths; both Mac tips preserved as `preserve/mac-3c87fac`, `preserve/mac-dirty-tree`), and fixing Windows `machines.txt` which still points `mac-18gb` at `/Users/nbiish/code`.

## Insights

- **Steps 2–4 of the old driver chain were router *routes*, not direct calls** — a live router with one dead vendor upstream failed all three against the same route while the real fallbacks sat behind unrequested vendors. Hence the transport↔id assertions, which catch a "transports reverted to `local-router`" regression that would otherwise surface as all fallbacks dying at once.
- **Profiling, not guessing, found the pi-priming defect**: elephant 6.9s, goldfish 33.5s over 3 calls, all `finish_reason=length` at 672 tokens — a reasoning model exhausts that on reasoning. Timing budget had been raised; token budget never was.
- **Measured `--thinking` as a cost lever**: one-word reply at `high` cost 6,904 input tokens vs 56 at `off`; elephant defaults `off`, goldfish `low`.
- **`pi` refuses ambiguous ids** (bare `glm-5.3-flash` across five providers), so explicit translation via `PI_MODEL_IDS` is required.
- **PQC vault is locked on this host**: `pqc-secrets export --json` prompts, `_pqc_export()` returns 0, `resolve_driver_key` → None for all three direct providers; `local-router` is unaffected because it needs no key. That is why it is the only reliably exercisable step.
- **`openrouter` reports `up` with no key** — its `/models` catalogue is public, so reachability passes while chat would 401 (recorded in `.agents/suggestions/2026-11-13-probe-conflates-reachability-with-auth.md`).
- **A bare commit hook (save ≠ commit)** left the edit→save→switch-machines workflow with no transport, motivating the watcher; the watcher decides *when*, bytes still move only through the proven sync path.
- **Windows runs an older `ainish-coder` (`1bd8865`, predates `--machine-link`)**, so peer-side mutation must be plain `git -C … branch …` over ssh, never the peer's CLI.

## Recurring

- **Fail-closed on a locked vault recurs across tasks**: direct providers skip with "no API key resolved"; pi reviewer falls back to `local-router`; driver steps 2–4 cannot be end-to-end verified here. Repeatedly flagged as correct behavior, not a defect.
- **"Sync all branches" / cross-machine state was repeatedly misleading**: remote-tracking refs are not checkout-able, peer paths were guessed wrongly, and `--status` is no-network so it never answered "which copy is newest." Materialization and newest-copy reporting both address this.
- **The no-common-ancestor constraint on Mac vs Windows `main`** forces every federation change to be strictly additive / refuse-and-report, never overwrite.
- **Baselines are explicitly tracked** so pre-existing failures aren't mistaken for regressions (e.g. the 6 pre-existing `test-machine-sync.sh` failures all exited 255).
- **Operator-reserved decisions recur**: convergence merges, the Windows registry fix, and paying for `zai` are all left to the operator rather than automated.

---

## Accomplished

- **watch-suggestions** (`2026-11-15-09-watch-suggestions.md`, `feat/watch-suggestions`, merged `e08333a`): closed four background-sync follow-ups. ssh re-probe moved to *failure-only* (per-cycle ssh round trip was the dominant cost), with `ssh-copy-id localhost` named in the diagnosis and state in `watch.state`. LaunchAgent plist path resolved via `git rev-common-dir` to the *main* checkout so worktree-based work isn't blocked. `wip(...)` message now lists changed paths (capped). Polling gained an optional `fswatch` fast path, polling retained as fallback. Gates stayed 29/29 watch, 60/60 sync. History was explicitly not squashed — `merge-base --is-ancestor` and `--latest` attribution both depend on SHAs. Scope: `src/machine_watch.sh`, `src/machine_sync.sh`, `src/help.sh`, `README.md`, `llms.txt`, `scripts/test-machine-watch.sh`. Plan: `.agents/plans/2026-11-15-09-watch-suggestions.md`.

- **context-priming-master** (`2026-11-17-19-context-priming-master.md`, `feat/context-priming-master`, merged `4979302`, 331 assertions pass): added a per-repo self-improving context harness to `ainish-coder --context` — a `PrimeProfile` plus learner-authored skill files from a contrastive propose/probe/gate loop seeded at `--rules`. The delivered artifact of this pass is **research**: `research/context-priming-master/` (8 docs, ~1,900 lines, plus raw sources — arXiv 2610.14224, both video transcripts, harness2 read at source level), entry point `README.md`. Key recorded findings: generation 0 is **frozen and mandatory** (`05-design.md`, R1) because the paper's worst case was degradation (Code 73.4 → 63.2) without reference execution and a library; `KEEP_BASE` is a first-class outcome because the video's elegant recursive harness merely *matched* the frozen three-tool harness; learned skills are **staged** under `.agents/context-harness/skills/` and promoted only by explicit operator action because `.agents/skills/` is standing prompt surface for every harness. Touched: `src/rag/rag.py`, `bin/ainish-coder`, `src/skills_selection.sh`, `src/deploy_skills.sh`, `scripts/test-pqc-dist.sh`, `.agents/context-harness/`.

- **wiki-pseudo-skills** (`2026-11-18-10-wiki-pseudo-skills.md`, `feat/wiki-pseudo-skills`, merged `748cb8a`, 354 assertions pass): fixed corpus coverage — `.agents/` held 115 files with 10 indexed and `research/` held 30 tracked files with 0 indexed. Learned pseudo-skills now live in `.agents/wiki/skills/` as markdown; `generate_wiki` owns seven filenames and globs non-recursively, so it never touches that subdirectory. `.gitignore:189` (`/**/.agents/wiki/`) was negating the root dir so learner output is trackable while nested `src/rag/.agents/wiki/` stays ignored. Scale measured: 658 projected nodes, 216k pairwise comparisons, 41 ms, cached on mtime. Scope: `src/rag/rag.py`, `src/rag/context_harness.py`, `.gitignore`, `scripts/test-pqc-dist.sh`.

- **context-harness-state** (`2026-11-18-14-context-harness-state.md`, `fix/context-harness-state`, done): bounded the harness state dir — `work/<stamp>/` (written per pass, never removed) and `rejected/<stamp>.md` (appended per refusal, never capped) are now capped, and per-machine traces are separated from clone-surviving learned state via `.agents/context-harness/.gitignore`. Scope: `src/rag/context_harness.py`, `src/rag/rag.py`, `scripts/test-pqc-dist.sh`.

## Unfinished

- **federation-discoverability** (`2026-11-17-13-federation-discoverability.md`, `feat/federation-discoverability`) — status `implementing`, stopped mid-flight. Goal: an agent following `--context` → `AGENTS.md` must learn cross-machine sync exists (`ainish-coder --help` names federation 25 times; `ainish-rag --help` and `AGENTS.md` name it 0 times, measured by `grep -c`). Blockers: `AGENTS.md` is at its hard 160-line cap (`scripts/test-pqc-dist.sh:866`), so the pointer row must be paid for by trimming prose, not by raising the gate; `ORIENT_PRIMER` is generated from the wiki vault and cannot carry hand-written guidance. Scope: `src/rag/rag.py`, `AGENTS.md`, `scripts/test-pqc-dist.sh`, `llms.txt`.
- **context-priming-master Phase 0** (T1) — the next action recorded for that branch: a throwaway script rendering retrieval for 8 real tasks under base/wide/narrow profiles, computing five signals, to decide whether they separate anything. Phase 1 must not start until it has.
- **context-harness-state** — only "commit, merge, remove the worktree" remained at the time of the record; no commit SHA is captured in the record itself.
- Known defect carried from `context-priming-master`: `src/deploy_skills.sh:181` sweeps target skill dirs absent from source only when a selection entry exists, so a promoted `learned-*` pack survives *by accident*; `_skill_learned` beside `_skill_mandatory` is required before that feature ships (R13).

## Insights

- `ainish-rag --context` had **no learnable state at all**: every ranking constant is a module-level literal (`rag.py:3489`, `:3591–3594`, `:3787`, `:3857`), hand-chosen for this repository. That is the opening the priming work exploits.
- `src/rag/rag.py` is stdlib-only — no embeddings, no vector store, no third-party dependency — and that constraint held through both merged context-harness changes.
- `.agents/rag/` is gitignored; learned state therefore goes to the tracked `.agents/context-harness/` instead. Learned content adds no new injection section; it rides inside the existing retrieval share with provenance carrying the metadata.
- A `--context` call must never block the task, which is why learning is a **separate verb**, not part of context rendering.
- Learned-skill reach is deliberately smaller than harness²'s: this repo has a prime that can only *point*, not a runtime that can *dispatch*. Recorded as a divergence, not an oversight.
- Fix ordering matters: the first attempt at the harness-state fix placed the prune call **after** `_harness_evidence_tree`, which would have made the newest evidence the first thing eligible for removal. Pruning now happens at the start of the pass.
- Discovery failure is a real failure mode, not cosmetic: an undocumented-in-the-right-place capability is indistinguishable from a missing one to an agent that reads only the contract and `--help`. Relatedly, `--context` orientation was advertising a finished task as active because the task record still said `implementing` after `e08333a`.

## Recurring

- **The AGENTS.md 160-line hard gate blocks several threads.** It is cited as a hard cap at `scripts/test-pqc-dist.sh:866` in federation-discoverability and at `:722`, `:878` in context-priming-master; the resolution in both cases is to pay for added text with trimmed prose rather than raise the gate (and in the latter, to add nothing). Every future pointer addition into that file inherits this constraint.
- **Unbounded growth in state that looks like it should persist** appears twice: `work/<stamp>/` and `rejected/<stamp>.md` in the harness state dir, and the ungitignored-wiki problem in wiki-pseudo-skills — both are cases where "we'll write it and it'll be fine" produces either unbounded commits or silently untracked output. The same underlying lesson: any directory the system writes to must have its tracking and retention decided explicitly.
- **Shipped fixes need a committed record, or gates lie.** The plan gate refused the harness-state commit until a plan existed (recorded as the gate working, explicitly *not* bypassed with `AINISH_SKIP_PLAN_CHECK`); the federation work needed a stale task record corrected. Two of five records are about the record being wrong rather than the code.
- **Constraints recur across all four done branches**: no new mandatory dependency (`fswatch`, stdlib-only `rag.py`), no weakening of existing gates (dirty-peer refusal, lock, backoff; 160-line cap), no history rewriting. The safe default chosen every time was additive-and-optional over change-the-invariant.

---

## Accomplished

**Single-command context entry point** (`2026-11-18-14-single-command-context.md`): `ainish-rag --context` now returns the rules digest inside `orientation` (never skipped, no model call) alongside the prime, and spawns the learning/harness-improvement detached *after* the prime is assembled, throttled by 6h + ≥1 new commit. Merged as 8321849; 342 assertions pass. Scope: `src/rag/rag.py`, `src/rag/context_harness.py`, `AGENTS.md`, `scripts/test-pqc-dist.sh`, `research/context-priming-master/10-single-command.md`.

**COMMS delimiter parsing** (`2026-11-18-15-comms-block-parsing.md`): the "today's COMMS, last entry" line previously split only on `### ` and printed the frontmatter fence (`---`) when ledgers used `---`. Parser now accepts both delimiter styles; historical ledgers left untouched. Branch `fix/comms-block-parsing`.

**Context-agent correctness overhaul** (`2026-11-19-14-context-agent-correctness.md`, 380 assertions): corpus indexing cap fixed (`BASE_PROFILE` capped artifacts at 2, indexing only 60/167 files; now 164 files / 411 nodes, caps are 0=all); graph edges bounded (`GRAPH_MAX_EDGES_PER_NODE = 24`, from 42,216/102-per-node down to 4,220/10-per-node); `KIND_INTENT` boosts the named layer so contract sections rank 1-2; naming a layer forces retrieval; acceptance referent is a task record at `status: done` with `--task-record` and `--outcome ok|fail|unknown` (`unknown` refuses); generation 0 seeded, generation 1 accepted, rollback verified (fingerprint `4e02eea77ff7f9d9`); rollback now moves profile + `.skills` snapshot; `_coverage_loss_guard` refuses narrowing; `--refresh-wiki` works on Python-generated vaults (SIGNED ledgers still refuse); skill surfaces unified to `.agents/context-harness/skills/`; three honest provenance states (`distinct-model`, `fresh-context`=PROVISIONAL, `refused`); weights applied per kind (presence, not truthiness); `--rag` fixed via `AINISH_BIN_DIR`; context-seed resolves worktree root. `MAX_LIVE_SKILLS` raised 3→8. `probe_corpus.py` top-5 kind presence rose 4/11 → 10/11.

**RAG/embedding retirement** (`2026-11-19-15-retire-rag.md`, 387 assertions): `src/rag/` → `src/context/engine.py`, ~7k-line Rust crate deleted (13,733 lines); `ainish-context` is the launcher, `ainish-rag` a deprecated shim; `--embed-config` removed; nine retired subcommands intercepted pre-parse; completions regenerated from live verbs. Signing moved to ML-DSA-65 in Python from a 32-byte seed. `audit sign` now writes `x.sig` (was `x.json.sig`, unread); `audit verify` compares envelope `sha256` to artefact (was fail-open existence check); `audit lock --update` reports UNSIGNED per artefact; keygen derives real ML-DSA-65 public key (was `sha256(priv)`); audit verbs resolve worktree root for receipts, canonical root for shared caches. `audit contract --verify-history`: 66 transitions ML-DSA-65 valid.

**Harness-attribution trailer hook** (`2026-11-20-09-identity-trailer-hook.md`, 397 assertions): `commit-msg` strips attribution trailers BEFORE the object exists (was `post-commit` after amend, and skipped when author was already correct); one table `scripts/harness-attribution.txt` read by hook/guard/rewrite; `Signed-off-by:` preserved (DCO); `setup-hooks.sh` installs both hooks idempotently via `--git-common-dir` (was `$(git rev-parse --git-dir)`, inert in worktrees; one checkout had 12 duplicate blocks); deploy uses `git rev-parse --git-path hooks`. 62 unpushed commits carried a trailer → 0 across `origin/main..main`; tree hash `a1e6f70e3ef6` unchanged. Only the 20 (task says 62 found, 20 rewritten per operator decision) unpushed commits rewritten; pushed history kept its trailers.

## Unfinished

All five tasks are marked done/merged. The only explicitly deferred item: pushed history in `2026-11-20-09-identity-trailer-hook.md` retains its attribution trailers by operator decision (recorded in the suggestions file, not fixed). No other records report incomplete work.

## Insights

- A rules/contract question can silently return *no rules at all*: `AGENTS.md` was absent from the retrieval corpus, and routing could hit `skip_retrieval` with zero contract content. Putting the rules digest in `orientation` (never skipped, no model call) is the fix (`2026-11-18-14`).
- Delimiter drift across append-only ledgers: two styles (`### ` and `---`) coexist; printing the fence looked like state was gathered when it wasn't — worse than omitting the line (`2026-11-18-15`).
- The prime contradicting the engine constant: `BASE_PROFILE` capped artifacts at 2 while the engine said unlimited, silently indexing 60 of 167 files. Deriving settings from the profile prevents re-divergence (`2026-11-19-14`).
- "A control that can never pass is not a control": requiring a verifiable merge sha would make the gate refuse forever because history was rebased across machines and all four historical task records name dead shas. Hence `corroborated: false` is recorded honestly rather than blocking (`2026-11-19-14`).
- Fail-open gates are the dangerous class: `audit verify` passed on `.sig` existence alone and reported PASS on a rewritten manifest; `audit sign` wrote a filename no reader used and returned success (`2026-11-19-15`).
- Worktree vs. main-checkout root resolution is a recurring correctness trap for anything that writes canonical state (context-seed, audit lock, hook install) (`2026-11-19-14`, `2026-11-19-15`, `2026-11-20-09`).
- Worktree git paths: `$(git rev-parse --git-dir)` points at `.git/worktrees/<name>`, a hooks dir git never reads; `--git-common-dir` is the shared path every checkout uses (`2026-11-20-09`).

## Recurring

- **Worktree-root resolution defects** appear in three records: context-seed landing in main (`2026-11-19-14`), audit lock writing the main manifest (`2026-11-19-15`), and hook install going to a git-dir git never reads (`2026-11-20-09`). Same class: canonical state written to the wrong checkout, fixed by resolving the worktree/common root.
- **Fail-open or no-op gates returning success**: acceptance needed commit-subject overlap (`2026-11-19-14`), `audit verify` existence-only pass and `audit sign` silent no-op (`2026-11-19-15`), the strip that existed but was unreachable because the guard exited early (`2026-11-20-09`).
- **Verify by read-back, not exit code**: manifests compared by digest, primes compared across launchers, tree hash compared before/after rewrite — verification consistently done by re-reading state rather than trusting a 0 exit.
- **Deliberate, recorded deviations** rather than silent downgrades: starting on `main` before the worktree (`2026-11-18-14`), `MAX_LIVE_SKILLS` 3→8 and accepting uncorroborated `status: done` (`2026-11-19-14`), stripping vs. rewriting trailers and rewriting only unpushed commits (`2026-11-20-09`).

---

## Accomplished
All items below are from the single source `2026-11-20-10-contract-identity-deploy.md` (branch `feat/contract-identity-deploy`, lane "now", status done/merged; plan at `.agents/plans/2026-11-20-10-contract-identity-deploy.md`).

- Corrected the authorship text in both `AGENTS.md` and `.agents/canonical/AGENTS.md`: Rule 4 now states the rule and the `Nanoboozhoo - embodied by {agent harness}` form, instead of naming the enforcement scripts `strip-harness-trailers.sh` and `commit-identity-guard.sh`.
- Made `ainish-coder --rules` deploy identity hooks into a target: it copies the harness table, stripper, and guard into `<target>/.agents/bin/` and installs `commit-msg` + `post-commit` blocks that call them (previously it installed none).
- Changed target hook paths to relative `.agents/bin/…` so hooks no longer point at the installing checkout; verified no absolute path to the source appears in a deployed target's hooks.
- Removed the dangling call to `deploy_embed_provider_detect` (deleted 2026-11-19) from `bin/ainish-coder`; `--rules` no longer prints `command not found`.
- Updated the test in `scripts/test-pqc-dist.sh`: the assertion now checks the rule is present AND that no enforcement script is named (it previously pinned the contract to a script filename).
- Verification (checkable): `scripts/test-pqc-dist.sh` → 407 assertions pass (397 baseline + 10 new), including a behavioural test that commits into a deployed scratch repo and asserts the trailer was stripped; `wc -l < AGENTS.md` = 160 with every non-negotiable grepping present; `ainish-context audit contract --verify-history` verified 66 transitions after re-signing; contract re-locked so a write fails with `operation not permitted`; a deployed target's hooks contain no reference to the installing checkout. Scope files: `AGENTS.md`, `.agents/canonical/AGENTS.md`, `src/deploy_rules_sync.sh`, `bin/ainish-coder`, `scripts/test-pqc-dist.sh`.

## Unfinished
Nothing. The task is recorded as done and merged, with verification listed above.

## Insights
- Both contract files are `uchg` (immutable flag) at mode 444. An edit to them silently fails with `operation not permitted` and the file stays byte-identical to HEAD — the operator's earlier edit had been refused this way without any visible error. Re-locking is deliberate; verify edits actually landed rather than trusting the write.
- The root cause of `--rules` deploying no identity hooks: `install_root_rules_sync_hook` writes to `${REPO_DIR}` (the source) and took no target argument. Fixing it required making hook installation target-aware, not just adding the files.
- Cross-session coupling bites: deleting a module in a prior session left a dangling caller (`deploy_embed_provider_detect`) that only surfaced later as `command not found` on every `--rules` run. Watch for orphaned callers after deletions/renames.
- Contract changes are signed and history-tracked; re-signing was required and `audit contract --verify-history` is the check (66 transitions).
- Deliberate tradeoff (operator's choice): Rule 4 no longer names where the tooling lives, so an agent cannot discover the harness table from the contract alone. Rationale — the contract is read on every task and script paths are implementation detail. Discovery belongs in `.agents/llms.txt` if ever needed.

## Recurring
Only one record exists for period 2026-11, so no cross-record recurrence can be established. Within this single record a weak pattern appears twice: prior changes orphaned references — a deleted module left a live caller, and an earlier edit had pinned a test to a script filename — both of which this task had to unwind. Treat as one observed instance, not a confirmed recurring theme.

## Review

The draft does not digest these sources at all. Every citation points to files outside the period (`2026-11-13-00-driver-chain-direct.md`, `2026-11-14-17-pi-agents-prime.md`, `2026-11-14-21-machine-link-federation.md`, `2026-11-15-09-watch-suggestions.md`, `2026-11-17-19-context-priming-master.md`); none of the five records in this batch appear anywhere in it.

Unsupported assertions (present in draft, absent from sources):
- Entire driver-chain / pi-priming / machine-link / branch-materialization / watcher / context-priming-master narrative. None of this is in the five records.

Omitted, checkable facts a future reader would lose:
- RAG repositioning: `ainish-rag` made an operator utility, not agent intake; commands unchanged; `context-orchestration` "Route"→"Read"; canonical re-signed ML-DSA-65 k=1; 57/57 `test-pqc-dist.sh`; fleet 3/3 CURRENT; cleanup of `D:\Code\ainish-coder-skills-select`, `-egm-master-memory`, kept `-rules-smoke` (`2026-11-05-rag-operator-utility-task.md`).
- Skill-selection regression: root cause `b268b75`+`fdd8537` (selector removed + default flipped to `off` → 19 "Deselected", zero-deploy); `_rules_deploy_skills` always/never/auto; 120s bounded selector; `--select-skills`/`--skills-list`; 51/51 then e2e 21/21, 4/4, 7/7; the SIGTTIN/WSL stdin-detach fix; `--pqc-install` no longer requires `bundleExists` (`2026-11-05-rules-skill-selection-task.md`).
- PQC cross-platform: `_decode_wsl_list()` UTF-8/UTF-16 autodetect fixing mojibake distro names; `run_cli` pinning `PQC_SECRETS_DIR`+`USERPROFILE` (HOME ignored by `pathlib`); gate fail-closed without `uv` (`AINISH_ALLOW_GATE_SKIP=1`); stamp fixture derived from `_ainish_stamp_alternative`; 73/73 on three hosts; macOS not executed; 13 WSL keys vs 0 Windows (`2026-11-06-pqc-crossplatform-task.md`).
- RAG Phase 0: `bench` now records nDCG@3, tokens, embedding identity, row count, engine commit; `compare_to_baseline` gates on recall+nDCG @90%, "incomparable" on identity change; `.gitignore` `/`-descend fix; `bin/ainish-rag` self-exec bug fixed; nDCG>1.0 bug fixed; baseline Recall@3=1.0/nDCG=1.0, 920 tokens, 3627 records, `api:openrouter:openai/text-embedding-3-small`, commit `fab34e1`; two Windows-only pre-existing failures; `local-router` corpus not baselined; Rust exe stale (`2026-11-06-rag-phase0-baseline-task.md`).
- Signing fail-fast: `_ainish_rules_require_signer` preflights before any write; signature deliberately not made optional; smoke sandbox cleared, stale enrollment removed via `--rules-unenroll`; 62/62; 2/2 CURRENT (local-router, ainish-coder-rules-smoke); decoupling ML-DSA from the engine deferred (`2026-11-06-signing-failfast-task.md`).

Verdict: the digest is about the wrong records entirely — unusable as a replacement for this batch.
