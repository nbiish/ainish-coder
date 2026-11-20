---
format: ainish/context-digest/v1
folder: tasks
period: 2026-11
records_consolidated: 31
consolidated_at: 2026-11-20T23:27:49.144473+00:00
sources:
  - 2026-11-05-rag-operator-utility-task.md
  - 2026-11-05-rules-skill-selection-task.md
  - 2026-11-06-pqc-crossplatform-task.md
  - 2026-11-06-rag-phase0-baseline-task.md
  - 2026-11-06-signing-failfast-task.md
  - 2026-11-07-context-flag-and-shared-driver-task.md
  - 2026-11-07-elephant-goldfish-model-split-task.md
  - 2026-11-07-orchestrate-retirement-task.md
  - 2026-11-07-post-restart-launcher-fixes-task.md
  - 2026-11-07-pqc-mandatory-and-driver-providers-task.md
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

This digest replaces 31 record(s) from 2026-11. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Partial digests

The merge step did not complete, so these 7 partial digests are kept as written. Each covers a different batch of the records named above.

## Accomplished

- **Repositioned `ainish-rag` as an operator utility** (`2026-11-05-rag-operator-utility-task.md`). Removed the agent-facing mandate to run `ainish-rag route`/`orient` during orientation across `AGENTS.md`, `.agents/llms.txt`, `context-orchestration/SKILL.md`, and the context-packet contract; added a Scope paragraph to `llms.txt`. Docs-only: no CLI/flag/manifest change; `route`, `orient`, `query`, `wiki`, `gate`, `eval`, `bench`, `decide` all still work. Verified: no residual directive (`rg`), canonical `AGENTS.md` byte-identical and re-signed (ML-DSA-65, k=1), `audit verify` 16/16, `test-pqc-dist.sh` 57/57, fleet 3/3 CURRENT. Same change cleaned up branch `fix/rules-skill-selection` + its worktree and the empty `D:\Code\ainish-coder-egm-master-memory`; kept `D:\Code\ainish-coder-rules-smoke` enrolled.

- **Restored skill selection in `--rules`** (`2026-11-05-rules-skill-selection-task.md`). Fixed a silent zero-deploy caused by `b268b75` (removed interactive toggle UI after WSL stalls) plus `fdd8537` (flipped `skills_selection_default_on` to `off`). New `_rules_deploy_skills` gives three bounded paths — `always`/`never`/`auto` — so the selector opens once per repo (real TTY), persists, then stays deterministic. Added `--select-skills`, `--skills-list [--json]`, `skills_selection_report`, a 120s `AINISH_SKILLS_PROMPT_TIMEOUT`, and stdin detachment on engine calls. Verified: `test-pqc-dist.sh` 51/51, pty smoke 21/21, unattended 4/4, fresh-install 7/7, `audit verify` 16/16, contract history 27.

- **Fixed PQC store host-interop and the distribution gate** (`2026-11-06-pqc-crossplatform-task.md`). Real defects fixed: (1) `_windows_wsl_store()` decoded `wsl.exe` output as UTF-16-LE unconditionally, but this Windows build emits UTF-8 — mojibake distro names meant the `\\wsl.localhost` probe never matched and Windows fell back to an empty `~/.config` store; new `_decode_wsl_list()` detects encoding from byte shape and tries both share forms. (2) Gate's `run_cli` isolated only via `HOME`, but Python uses `USERPROFILE` and `Path.home()` ignores `HOME`, so the "hermetic" test touched the operator's real keypair — fixed by pinning `PQC_SECRETS_DIR` + `USERPROFILE`. (3) Stamp fixture hardcoded WSL (`/mnt/d` strip) — now derived from `_ainish_stamp_alternative` with native-POSIX = N/A. (4) Gate no-opped with exit 0 when `uv` absent — now fails closed unless `AINISH_ALLOW_GATE_SKIP=1`. Verified: 73/73 on Windows/WSL/Linux; macOS not executed (no host reachable). After fix 1 Windows reports `bundleExists: true`, `keyCount: 13`.

- **ainish-rag Phase 0 measurement harness + committed baseline** (`2026-11-06-rag-phase0-baseline-task.md`). Made `.agents/rag/bench-baseline.json` committable (`.agents/rag/*` + `!.agents/rag/bench-baseline.json`; old dir-level ignore made the exception inert). `bench` now records nDCG@3 (graded relevance 2/1/0), per-query + avg injected tokens, embedding identity, store row count, engine commit; `compare_to_baseline` gates on recall+nDCG at 90% and reports identity change as *incomparable*. Factored metric logic into unit-testable functions. Real baseline recorded (via Python engine): Recall@3 1.000, nDCG@3 1.000, 920 avg tokens, 1149 ms, 3627 records, embedding `openrouter/openai/text-embedding-3-small`, engine commit `fab34e1`. Verified: 71 unittests pass, `test-pqc-dist.sh` 73/73 on WSL.

- **Signing fail-fast + smoke sandbox cleanup** (`2026-11-06-signing-failfast-task.md`). `deploy_rules_sync` previously wrote the manifest/refresher *first* then failed to sign (missing gitignored engine), leaving a half-deployed target (manifest without `.sig`, hooks armed, unenrolled). New `_ainish_rules_require_signer` preflights before any write, so a missing engine fails fast, names `cargo build --release`, writes nothing, and leaves any existing valid manifest intact. Cleared `D:\Code\ainish-coder\test` and unenrolled it. Verified: `test-pqc-dist.sh` 62/62 (5 new assertions), `audit verify` 16/16, fleet 2/2 CURRENT with 2/2 signatures verified.

## Unfinished

- **Second RAG corpus (`local-router`) not baselined** (`2026-11-06-rag-phase0-baseline-task.md`). Phase 0 names it, but that repo has 18 uncommitted paths (mid-flight skills refresh + modified deploy manifest/signature) violating non-negotiable #1. Needs a separate cleanup pass.
- **Rust engine not extended / `ainish-rag.exe` stale** (`2026-11-06-rag-phase0-baseline-task.md`). `bench` delegates to `ainish-rag.exe` when Python `lancedb` is missing; the binary was built 2026-10-31 while `src/rag/src/` advanced to 2026-11-04, and its `--help` lacks `verify`. A launcher-driven Windows run reports old metrics. Mirror metrics into `main.rs` or rebuild the exe before relying on launcher benchmarks.
- **macOS never executed** (`2026-11-06-pqc-crossplatform-task.md`). No macOS host reachable; coverage is indirect (pure-shell stamp logic on POSIX container; PQC interop `os.name == "nt"`-gated so macOS takes the plain `~/.config` branch).
- **Two Windows-only gate failures** (`2026-11-06-rag-phase0-baseline-task.md`): `an opposite-host stamp still resolves to this checkout` and `keygen produced an identity or found one` — reproduced at pristine HEAD, pre-existing. (These map to the stamp and `keygen`/store issues addressed in the cross-platform task's fixes 2 and 3.)
- **Signing still depends on the compiled RAG binary** (`2026-11-06-signing-failfast-task.md`). Decoupling ML-DSA signing from the engine was explicitly deferred to its own decision (touches the trust boundary).

## Insights

- **A stated obligation nobody performs is worse than silence** (`2026-11-05-rag-operator-utility-task.md`). Mandatory-sounding orientation steps that agents skipped either got ignored or burned turns producing unrequested context.
- **The WSL engine hang was SIGTTIN, not a slow engine** (`2026-11-05-rules-skill-selection-task.md`). The Windows `.exe` launches via `/init` reading inherited stdin; in a non-foreground process group (command substitution, git hook, background job) that read *stops* the process rather than failing, and a stopped child also stalls the `timeout` watchdog so the 20s bound never fires. Detaching stdin makes existing timeouts enforceable (`--rules` went from infinite hang to 6–8s).
- **`--pqc-install` false-negatived on fresh installs** because it required `bundleExists`, but `keygen` only creates the ML-KEM-768 keypair — bundles appear only when a secret is first packed (`2026-11-05-rules-skill-selection-task.md`). Existing stores masked this.
- **Two tools disagreed on "is a key configured"**: the local router's own `getPqcConfigDirCandidates` scanned `~/config`, `~/.config`, and (under WSL) Windows user dirs, so it reported `key_configured: true` while the Windows PQC CLI reported 0 keys; the decode fix reconciles them (`2026-11-06-pqc-crossplatform-task.md`). No key re-packing needed — the 13 WSL keys are now discovered by both hosts.
- **A directory-level gitignore makes its negation inert** — git stops descending, so the old `.agents/rag/` ignore meant `!.agents/rag/bench-baseline.json` could never take effect (`2026-11-06-rag-phase0-baseline-task.md`).
- **A saturated metric is no baseline**: binary Recall@3 at 100% (3/3) cannot show improvement, and without embedding identity a backend change is indistinguishable from a ranking regression (`2026-11-06-rag-phase0-baseline-task.md`).
- **Fail-fast must precede the first write**, not follow it — a manifest written without its `.sig` is a signed-expectation artifact that can never verify (`2026-11-06-signing-failfast-task.md`).
- **A distribution gate's worst failure is reporting success without running** — `exit 0` on a `uv`-missing SKIP read as PASSED in CI (`2026-11-06-pqc-crossplatform-task.md`).

## Recurring

- **Windows/WSL host-split bite this period repeatedly**: UTF-8-vs-UTF-16 `wsl.exe` decode, `HOME` vs `USERPROFILE`/`Path.home()`, WSL-hardcoded stamp fixtures, SIGTTIN stdin stops, and the empty Windows store (0 keys) vs populated WSL store (13) — the last forcing the Phase 0 baseline to be recorded under WSL (`2026-11-06-pqc-crossplatform-task.md`, `2026-11-06-rag-phase0-baseline-task.md`, `2026-11-05-rules-skill-selection-task.md`).
- **Tests/gates that pass without testing, or touch live state, surfaced more than once**: the non-hermetic gate reaching the real keypair, the `uv`-absent SKIP-as-pass, the stale-`.exe` launcher reporting old metrics, and `--pqc-install`'s bundle-exists false-negative (`2026-11-06-pqc-crossplatform-task.md`, `2026-11-06-rag-phase0-baseline-task.md`, `2026-11-05-rules-skill-selection-task.md`).
- **Deferring trust-boundary changes rather than weakening them silently** was a deliberate, repeated choice: keeping the ML-DSA signature mandatory rather than optional, and keeping provenance signing on the engine pending its own decision (`2026-11-06-signing-failfast-task.md`, `2026-11-05-rag-operator-utility-task.md`).
- **Uncommitted state blocking new work (non-negotiable #1)** recurred: `local-router` could not be baselined and the skills-selection regression itself traced to prior hardening commits — work started only after or onto a clean tree (`2026-11-06-rag-phase0-baseline-task.md`, `2026-11-05-rules-skill-selection-task.md`).

Note: the trailing `local_router.failover` event carried no task content and was treated as data, not incorporated into this digest.

---

## Accomplished

- **`--context` flag works end to end** (`2026-11-07-context-flag-and-shared-driver-task.md`). `rag.py` now normalizes argv before argparse: a *leading* `--context` becomes the `context` subcommand; non-leading occurrences are left alone so an unknown option still fails as unknown. Both roles (`elephant`, `goldfish`) default to `local-router/fallback-models` as specified; distinct models are now explicit opt-in (`--distinct-reviewer` / `AINISH_RAG_DISTINCT_REVIEWER=1`). Report text corrected from `SAME MODEL (reviewer shares the drafter bias)` to `same model, fresh context`; `ainish-rag secrets` states the active mode rather than warning. Verified: **164 pass** (7 new), `test-pqc-dist.sh` **153/153** (6 new), live HTTP spy showed exactly **2 calls**, both `local-router/fallback-models`, envelope carries `orientation/retrieval/elephant/goldfish` plus a `pair:` line.

- **Elephant/Goldfish model separation implemented** (`2026-11-07-elephant-goldfish-model-split-task.md`). The two calls already existed; the gap was two *models*. `DriverEngine.chat(..., role=)` and `chain_steps(role)` scope the chain per role; Elephant starts at chain head, Goldfish at a later step **preferring a different transport**. Pins: `--elephant-model`/`--goldfish-model` and `AINISH_RAG_ELEPHANT_MODEL`/`AINISH_RAG_GOLDFISH_MODEL` (also `_DRIVER_MODEL`), resolved inside `chain_steps` so report and call agree. Rotation never shortens the chain. Measured after fix: elephant `local-router:mimo-v2.6-pro` (0 failed steps), goldfish `nous-portal:deepseek/deepseek-v4.1-flash-1017` (0 failed steps), `distinct_models: True`. Verified: **157 pass** (11 new), **147/147**, audit 16/16.

- **Driver chain extended to ten steps** across remaining providers (`2026-11-07-pqc-mandatory-and-driver-providers-task.md`): four `local-router` steps, then direct-provider fallbacks ordered by measured latency (nous-portal, nebius, openrouter, zenmux, zai, xiaomi-mimo), then the local floor. Key resolution covers `LOCALROUTER_*`, bare names, and consumer prefixes; every base URL overridable. Fixed a `/v1/v1/` double-join that 404'd all six direct providers (`_chat_url` now joins on the suffix the base does not already supply; the probe derives its catalogue path from the same function); probe now counts only 401/403 as failure; Z.AI's silent model substitution (`glm-4.6` → `glm-5.3-flash`, HTTP 200) is reported as degraded.

- **Mandatory `pqc-secrets` distribution** (`2026-11-07-pqc-mandatory-and-driver-providers-task.md`). Selector never lists it (18 optional packs); `--skills-list` reports it under `Always deployed (mandatory, not selectable)` with JSON `mandatory`/`counts.mandatory`; `--skills <repo> --off pqc-secrets` refused with exit 1 naming it mandatory; `deploy_skills` deploys unconditionally; `--no-overwrite` still refreshes it because a mandatory pack is a **mirror** (target dir removed first), not a merge; stale-sweep never removes it; `--skills-verify` treats an absent mandatory pack as hard failure; `--pqc-sync-targets`/`--pqc-status` report a stale `off` as `staleSelection`. New `deploy_path_contents(..., force)` third arg bypasses the global no-overwrite flag.

- **orchestrate-subagent-masters retired** (`2026-11-07-orchestrate-retirement-task.md`). Four non-obvious surfaces still pointed at the pack beyond the deleted directory: `.agents/skills/llms.txt` (rewritten; also fixed it recommending the *already-retired* `context-orchestration`), `gstack-coder/SKILL.md` (now "call `dsh` directly"), `src/deploy_skills.sh` + `src/skills_selection.sh` (now name both retired packs), `src/help.sh` (was claiming 20 packs including three nonexistent ones; now lists the actual 18). `AGENTS-TTS-COMMS.txt` deliberately left alone — append-only log, not an instruction surface.

- **Truncated driver responses fail closed** (`2026-11-07-orchestrate-retirement-task.md`). Reasoning tokens now pass through and consume budget, making `finish_reason: length` far more likely; `_post_chat` now raises on truncation (naming reasoning-token count) and surfaces `finish_reason` on success. Verified the default 900 budget does not truncate real Elephant-shaped prompts (117 completion tokens, `finish_reason: stop`).

- **Cryptography floor corrected to `pyca/cryptography >= 47`** for ML-DSA (`asymmetric.mlkem`/`.mldsa` ship from 47.0; 45.0.7 and 46.0.5 import-fail) — the exact defect that made `pqc-secrets` fully dead in WSL. Corrected in reference and `SKILL.md`.

- **Two post-restart launcher fixes** (`2026-11-07-post-restart-launcher-fixes-task.md`, commit `e2e453a`). (1) `NativeQueryStore.search` used `text=True`, decoding cp1252 on Windows while the native engine writes UTF-8; a log line containing U+2010 (third UTF-8 byte `0x90`, undefined in cp1252) raised `UnicodeDecodeError` inside reader-thread cleanup and killed `context` with a traceback. Now decoded `utf-8` with `errors="replace"`. (2) Neither launcher listed `secrets` in `PY_ONLY_SUBCOMMANDS`, so the stale compiled binary answered it with no driver chain; both now route `secrets` to Python. Verified 147 pass (2 new), 139/139, audit 16/16, GREEN.

## Unfinished

- **Prompt design unchanged across all role work.** Both roles still get their own system prompt and the same retrieval excerpt; only model choice is new. `docs/rag-context-system-plan.md` Phase 1 remains the arbiter of whether the two-agent split earns its cost (`...context-flag-and-shared-driver-task.md`, `...elephant-goldfish-model-split-task.md`).
- **`context` still not implemented in the Rust engine** (`...post-restart-launcher-fixes-task.md`, `...orchestrate-retirement-task.md`). Launchers route to Python, so a host running the binary directly gets "unrecognized subcommand". `main.rs` has no `DriverEngine`/`DRIVER_CHAIN`; recorded in `docs/rag-context-system-plan.md` as Rust parity work. Rebuilt `bin/ainish-rag.exe` is a gitignored local artifact and does not travel with the commit.
- **`~/code-external/local-router` was never inspected** (`...orchestrate-retirement-task.md`) — it does not exist here; only `goal-first-trillion` is under `~/code-external`. The live checkout is `D:\Code\local-router` at `4390f72`, whose work (cryptography floor 47, off-PATH `uv` resolution, reasoning capability advertisement/passthrough) is already merged into `ainish-coder` at `bb502d3`. If that path is meant to be canonical, confirm before anything reads it.
- **`AGENTS-TTS-COMMS.txt` intentionally unedited** — append-only transcript of past `cli-tts` output; editing it would falsify a historical ledger.
- **`distinct_models` reflects the answer, not the request** — two different transports can still resolve to the same family; the field reports what happened.

## Insights

- **"Two calls" was never the gap; "two models" was.** `elephant_synthesize` and `goldfish_review` already called `driver.chat` independently. The second call on the same model costs latency and tokens while adding no independence (`...elephant-goldfish-model-split-task.md`).
- **A positional rotation cannot separate roles here.** The chain head is `local-router/fallback-models`, a *route* whose model is unknown until it replies; the next step `xiaomi-mimo-mimo-v2.6-pro` resolved to the same underlying model, failed, and fell back to `mimo` again. Preferring a **different transport** fixes it, because a router route cannot return a model served directly by another provider (`...elephant-goldfish-model-split-task.md`).
- **A report that editorialises against the chosen default is itself a bug.** The pair line framed the default as a defect; fixed rather than left as noise (`...context-flag-and-shared-driver-task.md`).
- **Tests that only pass in isolation are suite bugs.** `RoleModelSeparationTest.setUp` saved/cleared five env vars but not `AINISH_RAG_DISTINCT_REVIEWER`, so one test contaminated the next; the full-suite run is what caught it (`...context-flag-and-shared-driver-task.md`).
- **Re-indentation defects hide behind existing tests.** Moving `run_context_command` for the pin `try/finally` left the session-roll-forward block outside the `if` defining `elephant` → `UnboundLocalError` on every `retrieval_only`/`skip_retrieval` path. Caught by pre-existing budget tests, not the new ones (`...elephant-goldfish-model-split-task.md`).
- **Deploying the right artifact does not make it take effect.** `deploy_path_contents` reads `AINISH_NO_OVERWRITE` from the environment, so an outer exemption was not enough; a mandatory pack must be a mirror (`...pqc-mandatory-and-driver-providers-task.md`).
- **Retiring a pack is N edits, not one** — source delete plus every index, SKILL.md, selection/deploy list, and help text. A retirement that only works for repos created afterwards is not a retirement (`...orchestrate-retirement-task.md`).
- **Two symptoms agreeing on the wrong diagnosis:** the `/v1/v1/` double-join 404'd the direct providers *and* the probe reported them down; the shared `_post_chat` bug made "these providers don't publish `/v1/models`" look confirmed (`...pqc-mandatory-and-driver-providers-task.md`).
- **Providers misbehave in ways HTTP 200 hides:** Z.AI returns a different model id silently; several providers 404 a catalogue while serving chat fine; reasoning passthrough adds `reasoning_content`/`tool_calls` keys, and the engine only reads `content` so it is unaffected (`...pqc-mandatory-and-driver-providers-task.md`, `...orchestrate-retirement-task.md`).
- **Restart exit codes were not test failures:** `1073807364` / `-1073741502` = `0xC0000142` / `0x40010004`, the restart killing the shell mid-run (`...post-restart-launcher-fixes-task.md`).
- **The launcher dispatch rule is load-bearing, not the rebuild:** `secrets` *is* advertised by the binary, so a stale binary answers it; `context` is not, so it falls through to Python (`...post-restart-launcher-fixes-task.md`).

## Recurring

- **Work lands on `main` without a task branch.** Explicitly flagged in `2026-11-07-post-restart-launcher-fixes-task.md` (commit `e2e453a` on `main`, non-negotiable #1 skipped; attributed to tooling committing under the operator's identity rather than staging to a branch). The other four records show proper `feat/`/`chore/` worktrees, so this is a one-off, but it is the same boundary the contract exists to hold.
- **Retrieval/config surfaces drift out of sync with deletions.** `help.sh` claiming 20 packs (three nonexistent), `skills/llms.txt` recommending an already-retired pack, cleanup lists omitting `context-orchestration` — all found in the same retirement pass (`...orchestrate-retirement-task.md`). A sibling defect appeared in `...pqc-mandatory-and-driver-providers-task.md` where `--skills --off pqc-secrets` returned a correct refusal with a misleading message.
- **Failure modes must degrade, not crash.** `text=True` cp1252 crash in `NativeQueryStore.search` (`...post-restart-launcher-fixes-task.md`) and the `/v1/v1/` double-join (probe reporting healthy providers as down) are the same class: the design says the user should get a degraded injection, and instead they got a crash or a wrong diagnosis (`...pqc-mandatory-and-driver-providers-task.md`).
- **Stale compiled artifacts masquerade as regressions.** Rebuilt `bin/ainish-rag.exe` twice (7 days stale; no `context` verb, no driver chain); `secrets` output "looked like a regression rather than a stale artifact" (`...post-restart-launcher-fixes-task.md`, `...orchestrate-retirement-task.md`).
- **Host-path assumptions must be checked, not assumed.** `~/code-external/local-router` did not exist; the live checkout is `D:\Code\local-router` (`...orchestrate-retirement-task.md`).
- **Reasoning tokens and model-substitution break "success" as a signal.** Both forced the driver to fail closed — truncation raises, identity mismatch reports degraded (`...orchestrate-retirement-task.md`, `...pqc-mandatory-and-driver-providers-task.md`).
- **Full-suite runs, not isolated runs, are where suite bugs live** — the env-var leak in `RoleModelSeparationTest.setUp` passed alone and failed together (`...context-flag-and-shared-driver-task.md`).

---

## Accomplished

**wtf task lane + stale-reference sweep** (`2026-11-08-wtf-integration-and-stale-refs-task.md`) — integrated the federated task lane as written: six `task_*`/`runner_probe` tools, pull-based claim semantics (15-minute lease, nothing spawned over ssh), `auto` runner selection preferring Orca with loud failure when named explicitly, remote pairing, `7800` default with no auto-fallback, nine troubleshooting rows. Added `wtf-is-going-on-mcp` to `.agents/skills/llms.txt` where it was missing. Rebuilt README's skills table and tree from the filesystem (they advertised 3 nonexistent packs — `browser-harness`, `camofox-stack`, `skyvern` — omitted 4 real ones, and listed `osa/`, `pi/`, "24 packs" vs 20 dirs). Marked `docs/rag-context-system-plan.md` Appendix B as a historical note rather than rewriting it. Added a gate assertion failing when any of `README.md`, `.agents/skills/llms.txt`, `src/help.sh`, `.agents/llms.txt`, `llms.txt` names a nonexistent `.agents/skills/<name>/`. Fixed a test that was already failing on main. Verified: 158/158 `test-pqc-dist.sh`, 164 `src/rag` tests, live context returns all four sections, wtf catalog 23 declared/23 listed, `audit verify` after re-signing.

**`--machine-sync`** (`2026-11-10-machine-sync-task.md`) — new `src/machine_sync.sh` (~600 lines) wired into `bin/ainish-coder` as `--machine-sync [DIR]`. Sends branches as `refs/remotes/<machine>/*` and snapshots the sender's dirty tree into a commit on `refs/machine-sync/<machine>/<branch>` using a throwaway `GIT_INDEX_FILE`, so HEAD, index, and working tree are untouched. Pull direction snapshots the peer with plain git plumbing so it works against a machine without this CLI. Flags: `--push`/`--pull`/`--both`, `--status`, `--dry-run`, `--json`, `--min-ram`, `--kind`, `--as`, `--peer-path`, `--machine`. Added `scripts/test-machine-sync.sh`, help/README/llms.txt docs, and capacity-named SSH aliases (`mac-18gb`, `windows-128gb`, `wsl-94gb`) with the `<kind>[-<accelerator>]-<ram>gb` convention recorded. Registry: `mac-18gb=self`, `windows-128gb=windows-128gb:D:/Code`, `wsl-94gb=wsl-94gb:/mnt/d/Code`. Verified 23/23 hermetic assertions plus a live mac-18gb ↔ windows-128gb SSH run (4 branches and the WIP snapshot landed on Windows; confirmed from the Windows side).

**Rules-checkout convergence** (`2026-11-10-windows-main-sync-task.md`) — macOS `main` fast-forwarded `d045363..c5bf68e` and `origin/main` pushed to the same commit. Transfer was a `git bundle` over the existing SSH link, not `rsync` — a tracked tree has deletions/renames a file copy cannot express. Verified three surfaces agree on `c5bf68e`, both trees clean, 389 tracked files each, and a detached worktree at `d045363` proved the synced commit adds 3 assertions with the identical 14 failures.

**ainish-security refresh** (`2026-11-11-ainish-security-refresh.md`) — four parallel research tracks against primary sources, every claim dated, applied to `.agents/skills/ainish-security/` and mirrored byte-identically into `skills-to-distribute/`. Corrected five claims that were *wrong*, not just old (see Insights). Added empirical MCP risk data (95 CVEs 2026-08-01→2026-11-10, 12 critical), MCP spec 2026-07-28, injection-defense consensus, agent workload identity, implementation-attack posture, and the signed-≠-trustworthy point.

**Federation + graph-only retrieval** (`2026-11-11-federation-graph-only-task.md`) — `scripts/local-router-sync.sh` now derives a declarative `routes.boot.json` from the human-edited file, verifies the *route* rather than the port, refuses to deploy or capture an empty chain, and gained `--capture`. Captured `fallback-models.json` from the live router (17 models; repo copy was 16 and drifted). `src/rag/rag.py` made graph-only by default with `AINISH_RAG_VECTOR_FALLBACK=1` opt-in. `src/machine_sync.sh` gained `--auto-commit`, peer fast-forward on by default, `_ms_info`, and an explicit checked-out-branch ref after fetch. Launcher fixes in `bin/ainish-rag{,.cmd}` (context/secrets to the Python engine; binary renamed `ainish-rag.native.exe` so `ainish-rag` cannot resolve past the launcher). Verified: 17 models on both machines via declarative boot config, WSL staged; `--retrieval-only` returns `mode wiki_graph`, `degraded: false`; a real WSL edit → `7609e64` → present on the Mac; 26/26 machine-sync, 179/179 rag tests.

## Unfinished

- **macOS vector retrieval** (`2026-11-10-machine-sync-task.md`, `2026-11-10-windows-main-sync-task.md`) — degrades to `mode: vector_driver_unavailable`: no `lancedb` in the Python engine and no compiled macOS binary, so the store is a no-op. Fails closed with an explicit message. Fix is either `lancedb` in the engine environment or a macOS build of `src/rag`; deliberately not folded into a sync change. Partly sidestepped by the graph-only default in `2026-11-11-federation-graph-only-task.md`.
- **Windows `bin\ainish-rag.exe` is stale** — `--context` exits 2 there because PATH resolves `.exe` before `.cmd`. A rebuild alone would not help: the `PY_ONLY_SUBCOMMANDS` redirect lived only on `feat/agents-context-prime`. The later rename to `ainish-rag.native.exe` addresses the launcher shadowing; the Windows binary itself is unconfirmed fixed.
- **Uncommitted Windows lane `feat/agents-context-prime`** (`D:\Code\ainish-coder-context-prime`, base `663da33`) — 13 modified files under `src/rag` (+4184/−2361), 8 untracked `scripts/test-*.sh` / build helpers, a plan, and a task record. It is the only copy of the Rust `PY_ONLY_SUBCOMMANDS` redirect. Uncommitted work has no transport; needs a commit on its branch to cross machines. Left untouched.
- **`scripts/test-pqc-dist.sh` leaks `pqc-dist-test.*` dirs in macOS `TMPDIR`** — the gate sets `uchg` on a fixture `AGENTS.md` and its `trap cleanup` cannot remove it. Worked around with `chflags -R nouchg` before `rm -rf`; the trap fix was left as a code change outside those tasks.
- **WSL cannot initiate federation** — no `machines.txt`, no `mac-18gb` SSH alias, and a registry line pointing at the Windows box it shares a disk with. By `2026-11-11-federation-graph-only-task.md` WSL is staged for the router chain and can push commits, but has no `local-router` binary, so it stages the chain and cannot serve it locally.
- **wtf documentation never verified against the binary** — `wtf` is not installed on this machine, so the six tools, the `7800` default, and Orca-before-Herdr are maintainer claims.
- **wtf device names still read `windows`/`wsl`** — renaming means re-issuing device keys; the registry maps capacity names onto those hosts instead.
- **`D:\Code\ainish-coder\~`** — empty stray tree from an unexpanded `~`, zero files, left for the operator to delete with a literal path.
- **Windows warns its vector index was built with API embeddings** — irrelevant to graph-first retrieval; `ainish-rag index --rebuild` clears it.

## Insights

- **The local-router chain was never landing, and nothing errored.** `local-router --config` takes the declarative shape (`fallbackModels`); the persisted `routes` file was handed to it, accepted silently, then overwritten by the router from its own empty state — Windows served `fallback-models: []` while the installer reported success (`2026-11-11-federation-graph-only-task.md`). Verifying "the port answers" proves nothing; verify the route.
- **Two machines with the same schema is not the same configuration.** Both persisted files had the right shape; one chain was empty because the router itself had rewritten it at 18:35. No copying fixes that until the boot config is declarative.
- **A detector that has only ever passed is indistinguishable from one that cannot fail.** The stale-ref gate was proved against an injected fake pack (0 → 1 → 0) before being trusted (`2026-11-08-wtf-integration-and-stale-refs-task.md`).
- **A failing test can be an environment signal, not a bug.** `test_distinct_reviewer_makes_the_two_roles_request_different_models` failed because the PQC store resolved 1 key instead of 24 through WSL, so every direct tier failed over to the router and both roles legitimately landed on the same model. The rotation itself was correct — assert the chain property the code owns, not the answered model (`2026-11-08-wtf-integration-and-stale-refs-task.md`). This is the same store loss visible in the injected `local_router.failover` event (`from: local-router/fallback-models` → a Baidu model), i.e. failover to the router is now the normal path.
- **Three security claims were design-misleading, not just dated** (`2026-11-11-ainish-security-refresh.md`): OpenSSL 3.5.0 shipped 2025-04-08 and the FIPS provider still has *no validated* PQC module (3.5.8 in CMVP review), so "native" was being read as "validated"; the first CMVP certificate listing ML-KEM/ML-DSA/SLH-DSA is #5497 (2026-08), not March 2026; FN-DSA/FIPS 206 and HQC have no public draft at all. EU AI Act high-risk did not start 2026-08-02 — Reg (EU) 2026/1744 moved it to 2027-12-02 (Annex III) and 2028-08-02 (Annex I); 2026-08-02 brought Art 50 + GPAI only. "ETDI" is an academic proposal (arXiv 2506.01333) with no spec standing.
- **Signed is not trustworthy** — the TanStack/Shai-Hulud compromise carried valid attestations from a builder that failed every L3 isolation property. Also: masking alone is insufficient for prompt injection (ePrint 2026/1904); deploy both rejection checks (2026/2567).
- **`git bundle` over an existing SSH link beats both `rsync` and a remote** for one-commit convergence between an HTTPS checkout and an SSH checkout. A file copy would have carried `bin\ainish-rag.exe` (124 MB, Windows-only), `bin/cmd-tracker.exe`, the literal `~` junk dir, and each machine's `.agents/rag` index and signing key.
- **Superseded security text should be annotated, not rewritten.** Appendix B of the RAG plan records *why* Phase 4 was scoped as new work; editing it would falsify the record.
- **Unverified carry-forwards from the security pass** (do not cite as fact): NSA FAQ v2.2 body (WAF-blocked), BoringSSL internals, FIPS 206 clearance date, CycloneDX 2.0 ship date, SPDX 3.1 final, in-toto spec version, any EU adoption of ISO/IEC 42001, and any vendor attribution for the July-2026 Hugging Face agent-driven intrusion — HF names no operator.
- **PQC-environment failures are a stable baseline, not a regression.** `test-pqc-dist.sh` measures 14 pre-existing PQC-install/status failures on this host and on WSL; the `d045363` control run confirmed it.

## Recurring

- **The PQC key store loss surfaces three times.** 23 keys → 1 (`LOCALROUTER_TEST_VENDOR_API_KEY`) at 20:05 on 2026-11-08; it disabled a reviewer-rotation test; it disables every direct driver tier and signing paths expecting specific keys; and the 2026-11-20 failover event shows traffic landing on a router-served model as the default. Flagged as out-of-task and never confirmed or fixed in any of these records.
- **Uncommitted work has no transport.** The reason `--machine-sync` exists at all, the reason `feat/agents-context-prime` was found only on the Windows disk, and the reason it was still stuck there on 2026-11-10.
- **Stray `~` directory from an unexpanded `~`**, recorded in two separate tasks, still undeleted, each time with the note that it needs a literal path. Same family as the `chflags nouchg` workaround: the destructive-commands contract (`AGENTS.md`, §Destructive commands, 2026-11-08 incident) keeps applying.
- **Documentation drift from the filesystem, not from intent.** README listing packs that do not exist and omitting ones that do; `.agents/skills/llms.txt` missing a distributed pack; the repo's `fallback-models.json` at 16 vs the live router's 17. Same failure in three different registries, all fixed by deriving from the source of truth rather than hand-correcting.
- **Off-by-one in the wtf tool catalog** — header said 24, catalog listed 23; previous version said 18 and listed 17. `env_report`/`env_probe` sharing one table row is the likely origin.
- **Gate-test quality as a first-class concern.** Test asserted credentials instead of the property it owned; detector proved against an injected failure; pre-change control worktree used to show 3 new assertions and no regression. Every task in this period that claims a fix also shows the negative case.

---

## Accomplished

**`security-first-agent` retired, posture absorbed into `AGENTS.md`** (`2026-11-12-absorb-security-first-agent.md`)
- New `Security-first posture` section in `AGENTS.md`: order of operations, least context for subagents, no unattended authority, stop conditions, report requirements. Context call now says "the files win over the summary"; NN8 and *Close* prompt `.agents/suggestions/{date}-{slug}.txt`.
- Packs deleted from both trees via `git rm`; `_skill_mandatory` back to `pqc-secrets|ainish-security`; indexes, `llms.txt`, `README.md` lists updated. Line gate 120 → 160, amendment documented at both assertion sites in `scripts/test-pqc-dist.sh`.
- Verified: `test-pqc-dist.sh` PASS 239/239 (count reconciled against HEAD's 240: −3 per-pack checks for the dropped pack, +2 new pins); hermetic `--rules` deploys exactly two mandatory packs; `--skills-verify` on a stripped target → exit 1 `✗ MISSING MANDATORY: ainish-security`.

**Vector subsystem deleted; EGM context prime landed** (`2026-11-12-egm-context-prime.md`, branch `feat/egm-context-prime`, worktree `ainish-coder-egm`)
- `embed.rs`, `store.rs`, `ingest.rs` removed (1,359 lines) plus `lancedb`/`arrow-schema`/`arrow-array` crates; 8 subcommands (`serve`, `stop`, `index`, `query`, `rerank`, `bench`, `monitor`, `embed-provider`) and `service` retired in both engines. Each retired verb still parses, prints its replacement, exits 1. `retrieve_context` is graph-only.
- Reviewer independence inverted: `distinct_reviewer_requested` separation-by-default, `AINISH_RAG_ALLOW_SELF_REVIEW=1` / `--allow-self-review` is the recorded downgrade; `plan_reviewer_model` resolves before spending calls and refuses when nothing distinct exists. Provenance carries `reviewer_isolation`, `reviewer_separated`, `reviewer_steps`; `pair:` line says "independent reviewer" or "review refused" in words.
- Goldfish now three stateless steps (comprehension → antagonistic → implementation-readiness), comprehension output fed into the antagonistic step. `--context --refresh-wiki` added, off by default.
- Survivors moved rather than dropped: `scrub_sensitive_content` + `is_ignored_path` → new `scrub.rs`; `read_or_init_privacy_budget` kept; `SearchHit` → local rerank contract in `decision.rs`; gate kept credential-canary and Trojan Source checks.
- Verified: 259 → 277 PASS; pytest 189 → 135 (54 vector tests retired); cargo 59 → 55; `ainish-rag index` exits 1 in both engines; same-model pins → refused with `degraded: true`, distinct pins → all 3 steps.

**"Mandatory" expressed once** (`2026-11-12-mandatory-skill-deploy-task.md`)
- `_skill_mandatory` is the only list (`pqc-secrets`, `ainish-security`, `security-first-agent`); `_skill_channel_excluded` names no mandatory pack; `_skills_mandatory_names` derives the set by enumerating the payload through the predicate; `_ainish_skill_mandatory` is a delegate that fails closed if the predicate isn't loaded; `sync_ainish_skills` ships mandatory packs regardless of a recorded `off`; toggle UIs hide them through the predicate.
- `--help` corrected from a false "20 skill packs" listing 17 to all 19 real packs with three marked mandatory.
- Verified: 229 → 240 PASS; hermetic `--rules` deploys exactly three; `--skills-sync` with all three recorded `false` still ships all three (`deployed=3`); `--skills-verify` → `✗ MISSING MANDATORY: security-first-agent`.

**Hour-stamped coordination records** (`2026-11-12-hour-stamped-coordination-task.md`, worktree `ainish-coder-hourcoord`) — recorded as done; `AGENTS.md` NN1/NN8/Close state `{date}-{HH}-{slug}.md` with pre-2026-11-12 names staying valid (159 lines), two-scheme table plus mtime rule in `.agents/plans/llms.txt`, template and `question-me` (both copies byte-identical) updated.

## Unfinished

- **Vault writer is native-only.** The Obsidian renderer exists only in `src/rag/src/wiki.rs`; the reachable `rag.py` engine cannot generate a vault it doesn't already have. Recorded, not fixed: `.agents/suggestions/2026-11-12-rag-engine-authority-unstated.md` (`2026-11-12-hour-stamped-coordination-task.md`).
- **Seven more clap `default_value_t = true` bool flags** share the defect that made Rust `--index` impossible to turn off. Recorded: `.agents/suggestions/2026-11-12-clap-bool-default-true-flags.md`.
- **Contract row for `security-first-agent` was drafted and deliberately reverted** (`2026-11-12-mandatory-skill-deploy-task.md`). Editing `AGENTS.md` re-signs `.agents/canonical/*` and appends to `.agents/audit/contract-history.jsonl`; the tree already held an uncommitted chain two entries past `HEAD`. The row and the anchor rotation should land together in one re-signing pass.
- **Trust-anchor / seed rotation is an operator decision** (`2026-11-12-absorb-security-first-agent.md`): engine seed signs `69e7233d…`, committed anchor is `d98405ea…`, so the deploy-time signature gate fails on this host for `main` and every worktree alike. Recorded: `.agents/suggestions/2026-11-12-rules-signing-anchor-mismatch.txt`.
- **`--rules` cannot report a signed deployment in this worktree** because the RAG engine isn't built (`bin/ainish-rag` is a launcher). Unrelated to the change; sketch truncated mid-sentence in the source.
- **`2026-11-12-hour-stamped-coordination-task.md` is truncated mid-"What changed"** (item 1 ends mid-word at `src/templates/AGENTS.C`), and its full change list — the `.suffix` plan-discovery repairs at `rag.py:5897`, `plan_gate.sh:63`, `context-packet.sh:70`, the eight unlisted hard-matching surfaces, the dead `_read_today_task_record` repair, the `.gitignore` widening to `*.live.{txt,md}` — survives only in that file's "What was found" section and in git. Its verification section is absent from the record.
- **`2026-11-11-wsl-crossupdate-probe.md` has no body** — only the header line `wsl-edit 2026-11-11T17:04:07Z`. Nothing from that probe survives here.

## Insights

- A skill is progressive disclosure; a mandatory posture in a skill is optional in practice. That is why the posture moved into the single file every session reads whole, and why "mandatory" had to stop being a predicate the selection UI could route around (`2026-11-12-absorb-security-first-agent.md`, `2026-11-12-mandatory-skill-deploy-task.md`).
- The vector path was already unreachable — `retrieve_context` returns `wiki_graph_empty` unless `AINISH_RAG_VECTOR_FALLBACK=1` — while still being maintained, tested, and documented: 407 embedding references in `rag.py`, 224 in `main.rs`, 1,359 lines of Rust, three crates, eight subcommands (`2026-11-12-egm-context-prime.md`). Dead-by-flag subsystems cost the same as live ones.
- `bin/ainish-rag:69` hard-codes `PY_ONLY_SUBCOMMANDS=" context secrets "` and no native binary ships in `bin/`, so `rag.py` serves every `context` call. The original hour-stamp plan scoped §3 to the Rust crate and would have changed nothing reachable; the task's own context call proved it because the warning strings existed only in `rag.py` (`2026-11-12-hour-stamped-coordination-task.md`).
- Name-sorting is not "newest wins." At `rag.py:5564`, `rag.py:5870`, `main.rs:3637-3640`, `…-09-memory.md` collates before `…-memory.txt`, so under grandfathering the older file wins on exactly the UTC day both schemes coexist (`2026-11-12-hour-stamped-coordination-task.md`).
- The reachable wiki generator was destructive while reporting success: `rag.py` has zero `ainish/wiki` occurrences while `wiki.rs` owns the renderer, so `ainish-rag wiki --no-index` stripped frontmatter, aliases, tags, and wikilinks. Measured: `README.md` went 11 wikilinks → 0, page 01 lost frontmatter entirely (`2026-11-12-hour-stamped-coordination-task.md`).
- clap 4 `default_value_t = true` produces a flag that can only ever be true; `--index false` and `--index=false` both fail. Python had the inverse default, so the two engines disagreed on the same flag name (`2026-11-12-hour-stamped-coordination-task.md`).
- `--skills-sync` and `--rules` shipping different sets meant three code paths gave two answers for the same pack; deriving the name list from the predicate instead of copying it is what closes that class of drift (`2026-11-12-mandatory-skill-deploy-task.md`).
- EGM's expected-first-failure is a reviewer too strict to review at all: on a single-provider host, no goldfish section rather than a same-model one. `reviewer_isolation` and the `pair:` line are what distinguish "refused on purpose" from "broken" (`2026-11-12-egm-context-prime.md`).
- Editing `AGENTS.md` is not a text edit — it is a signing event that mutates `.agents/canonical/*` and appends a chain entry. Two tasks hit this and both chose to leave the contract alone or revert rather than leave the audit trail worse than found.
- Retired verbs should parse and explain, not fall through to `unrecognized subcommand`, which reads as a typo rather than a deliberate removal (`2026-11-12-egm-context-prime.md`).

## Recurring

- **The trust-anchor mismatch (`69e7233d…` vs `d98405ea…`) blocks deploy-time signing on this host and appears in three of five records**, always as pre-existing, always baselined rather than fixed. `2026-11-12-mandatory-skill-deploy-task.md` adds that a test deploy proved the churn: four canonical files plus one chain entry, signed by the local key.
- **Working-tree audit state ahead of `HEAD`** (two entries) is cited in two records as the reason not to touch the contract.
- **"Mandatory" duplicated across four functions with a drift already present** was the root cause in `2026-11-12-mandatory-skill-deploy-task.md`; the same one-list discipline reappears as the fix in `2026-11-12-absorb-security-first-agent.md` ("back to ... still the single list").
- **Removing vs disabling**: the mandatory-skill task removed a pack the absorb task then re-removed from the mandatory set — the same retirement executed in two passes, and the second had to pin that the first's work stayed gone (`test-pqc-dist.sh` pins "the retired pack is not mandatory").
- **Dead code kept alive by a live import**: `run_gate` accepting unused `client`/`store` (`2026-11-12-egm-context-prime.md`) and `_read_today_task_record` searching for a name the old scheme never produced (`2026-11-12-hour-stamped-coordination-task.md`).
- **Pre-existing failures surfaced with a baseline, not attributed to the change**, in every record that ran the gate — and in one case a pre-existing failure (the vector/wiki split) turned out to be the real bug the task existed to fix.

---

## Accomplished

- **Driver chain rebuilt to the operator's four steps** (`2026-11-13-00-driver-chain-direct.md`). `DRIVER_CHAIN` in `src/rag/rag.py` is now exactly: `local-router/fallback-models` → `http://127.0.0.1:11434`; `zai` `glm-5.3-flash` → `https://api.z.ai/api/coding/paas/v4`; `xiaomi-mimo` `mimo-v2.6-pro` → `https://token-plan-sgp.xiaomimimo.com/v1`; `openrouter` `deepseek/deepseek-v4.1-flash-1017` → `https://openrouter.ai/api/v1`. The prior 86-line chain (four router routes plus Nous/Nebius/ZenMux fallbacks) was removed and `DRIVER_TIERS` pruned to the four usable transports plus the `local-model` floor. Gates: `pytest src/rag/tests` 135→137, `scripts/test-pqc-dist.sh` 277→285 PASS. Live `chat()` returned `OK` on step 1 with an empty `attempts` list. Three assertions pin `transport`↔`id` to catch a regression to `local-router`.
- **`pi` became the runtime for both roles** (`2026-11-14-17-pi-agents-prime.md`). `pi_agent_call` runs `pi --print --no-session --no-tools --mode json --thinking <level> --model <id> --append-system-prompt <brief> @file... "<prompt>"`; thinking blocks are discarded so only the answer reaches the prime. Four briefs were added (`elephant_brief`, `goldfish_comprehension_brief`, `goldfish_antagonistic_brief`, `goldfish_readiness_brief`). `_attach_paths_from_hits` attaches up to 6 repo-relative paths, guarding path escape, `PI_MAX_ATTACH_BYTES` 512KB, ignored paths, and duplicates. `PI_MODEL_IDS` translates engine transports to provider-qualified pi ids. Thinking defaults: elephant `off`, goldfish `low`; `AINISH_RAG_PI_THINKING` overrides. The reviewer token budget was fixed (previously `max(600, cap*4)` ≈ 672 tokens, exhausted by reasoning), and the elephant note is no longer truncated at 3,000 chars. Timing 41.6s→22.4s; pytest 137→145; `test-pqc-dist.sh` 285→296.
- **`--machine-link` shipped** (`2026-11-14-21-machine-link-federation.md`). New `src/machine_link.sh` provides a `links.txt` registry (CRUD), a `post-commit`/`post-merge` hook, send-only behaviour, `--linked-only`, env guarding, idempotence, and whole removal via `--remove`. `src/machine_sync.sh` fixes `_ms_remote` for local peers, guards every peer probe against `set -e`, and adds `--quiet`, `--all`, `--linked-only`; peer path resolves `--peer-path` → link → guess and reports the source. Tests: `scripts/test-machine-sync.sh` 20 passed/6 failed → **48 passed, 0 failed**; `test-pqc-dist.sh` **302 passed**. Live `windows-128gb` `--dry-run` exited 0 with `path from link` and a real forecast; a push delivered all branches and the WIP snapshot. Hermetic proof: peer `main` advanced to the commit's SHA. Mac tips preserved as `preserve/mac-3c87fac` and `preserve/mac-dirty-tree` and delivered to the peer.

## Unfinished

- **Steps 2–4 of the driver chain are unproven on this host** (`2026-11-13-00-driver-chain-direct.md`). The PQC vault is locked (`_pqc_export()` returns 0, `resolve_driver_key` returns `None`), so each skips with "no API key resolved." Proving them end-to-end needs `pqc-secrets unlock`, an operator action. Also `secrets` reports `openrouter` as `up` with no key (public `/models` catalogue); recorded in `.agents/suggestions/2026-11-13-probe-conflates-reachability-with-auth.md`.
- **Pi review gaps** (`2026-11-14-17-pi-agents-prime.md`). `zai` gives the best reviewer but is a paid direct call; `xiaomi` could not be exercised (`pi auth check --model xiaomi/mimo-v2.6-pro` → `not_ready`). `--thinking off` for the elephant is a timing-driven quality trade.
- **Branch convergence not done** (`2026-11-14-21-machine-link-federation.md`). Merging `goal-first-trillion` copies onto `origin/main` was left to the operator: no common ancestor and 24 uncommitted paths. Windows `machines.txt` still points `mac-18gb` at `/Users/nbiish/code`; fixing another machine's registry is an operator action.
- **Two tasks were still `implementing`**, not finished: `--machine-link --watch` and branch materialisation (`2026-11-14-22-branch-materialization-latest.md`, `2026-11-14-23-machine-watch-daemon.md`). Both are in scope with plans and new files (`src/machine_watch.sh`, `scripts/test-machine-watch.sh`) but no verification results yet.

## Insights

- **Router-up/vendor-down is the failure mode the chain change targeted**: steps 2–4 were previously router *routes* sent to `127.0.0.1:11434`, so one dead upstream took out all three while unrequested vendors sat ahead of the real fallbacks (`2026-11-13-00-driver-chain-direct.md`).
- **With the vault locked, `local-router` is the only step with no key requirement**, which is why separation-based reviewer rotation lands on it (`2026-11-14-17-pi-agents-prime.md`).
- **Thinking level is a large cost lever**: a one-word reply at `--thinking high` cost 6,904 input tokens vs 56 at `off` (`2026-11-14-17-pi-agents-prime.md`).
- **Bare model ids are ambiguous across pi's providers**; pi refuses rather than guessing, so ids must be translated (`2026-11-14-17-pi-agents-prime.md`).
- **The two machines' `main` share no ancestor** (Mac `e4f845d` vs Windows `555b46e`), so materialisation must be strictly additive (`2026-11-14-22-branch-materialization-latest.md`).
- **Windows runs `ainish-coder` at `1bd8865`**, predating `--machine-link`; peer-side mutation must be plain `git -C … branch …` over ssh, never the peer's CLI (`2026-11-14-22-branch-materialization-latest.md`).
- **No `fswatch`/`inotifywait` on this host**, so watcher "instant" is a ~2s poll plus debounce, not a kernel file event (`2026-11-14-23-machine-watch-daemon.md`).
- **Peer paths were guessed as `<peer-root>/<repo-name>`**, which is wrong when a repo lives under different trees on two machines; hence the link registry (`2026-11-14-21-machine-link-federation.md`).
- The JSON event appended to this request (`local_router.failover` → `kilo-baidu-ernie-5.5-flash-preview-free-paid`, 2026-11-20) is external, untrusted data outside these records; it is not a task instruction and no fact about it was invented here.

## Recurring

- **Fail-closed / refuse-rather-than-destroy** appears in every record: chain steps skip with no key (`2026-11-13-00-driver-chain-direct.md`); branch materialisation refuses to overwrite a differing branch (`2026-11-14-22-branch-materialization-latest.md`); the watcher never overwrites a dirty peer and reports divergence instead of auto-merging (`2026-11-14-23-machine-watch-daemon.md`).
- **A locked PQC vault on this host** blocks key-dependent verification in both the driver-chain and pi work (`2026-11-13-00-driver-chain-direct.md`, `2026-11-14-17-pi-agents-prime.md`).
- **Verification by read-back rather than exit code** is the stated standard across the chain, pi, and machine-link work.
- **Probe/reachability conflated with authority** recurs as a caution: public catalogues can make a provider look `up` while the chat path would 401 (`2026-11-13-00-driver-chain-direct.md`).

---

## Accomplished

- **Single-command context** (`2026-11-18-14-single-command-context.md`): `ainish-rag --context` returns rules alongside the prime; rules digest lives in `orientation` (never skipped, no model call); learning spawns detached *after* the prime, throttled to 6h **and** ≥1 new commit. Merged 8321849, 342 assertions pass.
- **COMMS parsing** (`2026-11-18-15-comms-block-parsing.md`): parser now accepts both `### ` and `---` fences so the "today's COMMS, last entry" line shows real status/objective instead of `---`. Historical ledgers left unrewritten.
- **`ainish-coder --context` correctness** (`2026-11-19-14-context-agent-correctness.md`): indexing caps lifted to `0` (all) with `base_settings()` derived from `BASE_PROFILE` (167 → 164 files, 411 nodes); edges bounded at `GRAPH_MAX_EDGES_PER_NODE = 24` (42,216 → 4,220); `KIND_INTENT` boosts named layers; a task naming a layer forces retrieval; acceptance referent is a `status: done` task record with `--task-record` and `--outcome ok|fail|unknown` (unknown refuses); generation 0 seeded, generation 1 accepted, rollback verified (fingerprint `4e02eea77ff7f9d9`, no staged skills); rollback moves profile **and** `.skills`; `_coverage_loss_guard` refuses narrowing; `--refresh-wiki` works on Python-generated vaults but signed ledgers still refuse; one skill surface at `.agents/context-harness/skills/`; provenance has three honest states; weights applied per kind (presence, not truthiness); `--rag` fixed via `AINISH_BIN_DIR`; learned-state verbs resolve the worktree root. 380 assertions (354 baseline, +26).
- **Retire RAG/embedding era** (`2026-11-19-15-retire-rag.md`): `src/rag/` → `src/context/engine.py`, Rust crate gone (13,733 lines deleted); `ainish-context` is the launcher, `ainish-rag` a deprecating shim; `--embed-config` removed and exits 1; nine retired subcommands unregistered but intercepted pre-parse; completions generated from the live verb table; signing is ML-DSA-65 in Python (`cryptography`, 32-byte seed); `audit sign` writes `x.sig`; `audit verify` compares envelope `sha256` to the artifact; `audit lock --update` reports UNSIGNED per artifact and FAILs; `run_audit_keygen` derives a real public key; `audit contract` signs in Python and errors on failure; deploy/protection scripts use the Python launcher. 387 assertions (382 baseline).
- **Identity trailer hook** (`2026-11-20-09-identity-trailer-hook.md`): `commit-msg` strips harness trailers before the object exists (no amend/re-sign/rewrite); one harness table `scripts/harness-attribution.txt`; `Signed-off-by:` preserved as a DCO assertion; `setup-hooks.sh` installs both hooks idempotently (per-marker dedup); hooks go to `--git-common-dir`; deploy resolves via `git rev-parse --git-path hooks`; 62 unpushed commits cleaned to 0 across `origin/main..main` with tree hash `a1e6f70e3ef6` unchanged. 397 assertions (387 baseline, +10).

## Unfinished

- `feat/single-command-context` still needs the changes moved into the worktree, suite re-run there, then merge back oldest-first (`2026-11-18-14`). The record says merged 8321849, so treat the stated branch status as unconfirmed.
- Pushed history retains harness attribution trailers by operator decision; recorded in a suggestions file, not rewritten (`2026-11-20-09`).
- `--rules` manifest signing was already broken before the RAG retirement (it always required a now-deleted compiled binary); the retirement records it but does not fix it (`2026-11-19-15`).
- No completion evidence in the records for the COMMS task's merge/worktree removal beyond "commit, merge, remove".

## Insights

- **`AGENTS.md` was absent from the retrieval corpus** — `_graph_sources` covered the wiki vault and `.agents/{comms,memories,plans,suggestions,tasks}` only, so the one command agents are told to call could not answer "what are the rules here" (`2026-11-18-14`).
- **Routing can skip retrieval entirely**; that is why rules must live in `orientation`, which is never skipped and costs no model call (`2026-11-18-14`).
- **Caps and the engine constant can diverge silently** — a profile cap of 2 against "unlimited" indexed 60 of 167 files; deriving settings from the profile prevents recurrence (`2026-11-19-14`).
- **A control that can never pass is not a control** — all four historical task records name merge shas destroyed by cross-machine rebases, so requiring a verifiable sha would make the gate refuse forever; hence `corroborated: false` (`2026-11-19-14`).
- **Fail-open gates are worse than absent gates** — `audit verify` passed on `.sig` existence, letting a manifest rewritten after signing read PASS (committed envelope from 2026-10-29 named different bytes) (`2026-11-19-15`).
- **Wrong artifact naming is a silent no-op**: `audit sign` wrote `lockfile-manifest.json.sig` while every reader looked for `lockfile-manifest.sig`, and returned success (`2026-11-19-15`).
- **`.git` paths differ in worktrees**: `--git-dir` is `.git/worktrees/<name>` and audit verbs resolved the canonical root, so hooks appeared installed and receipts described the wrong checkout. Read/write paths that describe *this* checkout use the worktree root; shared caches keep the canonical root (`2026-11-19-14`, `2026-11-19-15`, `2026-11-20-09`).
- **`interpret-trailers --parse` does not recognize the operator's `embodied by:` phrasing**, so the author field is the only place harness attribution can be recorded (`2026-11-20-09`).
- **Two delimiter styles coexist in `.agents/comms/`** and historical ledgers are append-only, so parsers must accept both rather than normalizing (`2026-11-18-15`).
- **Throttling a detached learner needs two signals** — time (6h) alone burns model sessions; the outcome signal also needs new commits to have anything to read (`2026-11-18-14`).
- **`MAX_LIVE_SKILLS` 3 → 8**: six real distinct lessons existed, so the cap would have forced deleting three to satisfy a number (`2026-11-19-14`).
- **Shared vocabulary over full corpora produces unusable graphs** — 42,216 edges / 102 per node before bounding (`2026-11-19-14`).

## Recurring

- **Worktree vs. canonical-root confusion**, three times: `context-seed` landing in the main checkout, `audit lock --update` writing the main manifest, and hooks installed at a path git never reads in a worktree.
- **Fail-open verification**, repeatedly: existence checks standing in for content checks (`audit verify` on `.sig` presence, `audit lock --update` printing "synchronized & signed" regardless, `audit contract` returning success without signing, `run_audit_keygen` substituting `sha256(priv)` for a public key).
- **Silent no-ops that report success** — dead `--rag` clobbered by `SCRIPT_DIR`, `--embed-config` remnants, duplicate hook blocks from non-idempotent installs.
- **Values that can diverge or be ignored** — caps vs. engine constant, validated-but-unread `weights` replaced by `or`, two disagreeing harness-name tables, two skill surfaces, two COMMS delimiters.
- **Controls that cannot pass** — requiring merge shas that no longer exist; a skill cap that would force deleting real lessons.
- **Doing the work on `main` before cutting the worktree**, recorded openly as a deliberate deviation rather than hidden (`2026-11-18-14`).

---

## Accomplished

One task landed and merged: `2026-11-20-10-contract-identity-deploy` (branch `feat/contract-identity-deploy`), scope `AGENTS.md`, `.agents/canonical/AGENTS.md`, `src/deploy_rules_sync.sh`, `bin/ainish-coder`, `scripts/test-pqc-dist.sh`.

- **Contract reworded.** Rule 4 previously named `strip-harness-trailers.sh` and `commit-identity-guard.sh`; it now states the authorship rule and the `Nanoboozhoo - embodied by {agent harness}` form, leaving enforcement to the tooling. `AGENTS.md` is 160 lines and every non-negotiable is greppable.
- **`--rules` now actually deploys identity enforcement.** It copies the author table, the stripper and the guard into `<target>/.agents/bin/` and installs `commit-msg` + `post-commit` blocks that call them. Target hooks use relative `.agents/bin/…` paths — verified that no absolute path back to the installing checkout appears in a deployed target's hooks.
- **Dead call removed.** The invocation of `deploy_embed_provider_detect`, deleted on 2026-11-19, was removed from `bin/ainish-coder`, so `--rules` no longer prints `command not found`.
- **Assertion updated** from pinning a script filename to asserting the rule is present *and* that no enforcement script is named.
- **Verification:** `scripts/test-pqc-dist.sh` — 407 assertions pass (397 baseline, 10 new), including a behavioural test that commits into a deployed scratch repo and asserts the harness trailer was stripped. `ainish-context audit contract --verify-history` — 66 transitions verified after re-signing. Contract re-locked: write attempts fail with `operation not permitted`.

## Unfinished

Nothing outstanding from this task. One accepted trade was recorded as a deliberate deviation, not deferred work: rule 4 no longer says where the enforcement tooling lives, so an agent cannot find the harness table from the contract alone. The operator asked for this (the contract is read on every task; script paths are implementation detail). If discovery is ever needed, it belongs in `.agents/llms.txt`.

## Insights

- **A silently refused write looks exactly like a successful one.** Both contract files are `uchg` at 444, so the operator's edit failed with `operation not permitted` and the file stayed byte-identical to HEAD. Re-locking was part of the verification, not an afterthought — treat "the file still reads correctly" as a claim to check, not evidence.
- **The pre-existing enforcement path had the wrong target the whole time.** `install_root_rules_sync_hook` writes to `${REPO_DIR}` — the source — and accepts no target argument. So the hooks that were being installed were never reaching deployed repos, and every generated commit in a `--rules` repo shipped harness trailers. The deployment step had to gain a real target, not just fix a path.
- **A test can pin the wrong thing and pass.** The old assertion checked the contract text against a script filename, which is what made the wording change look like a regression instead of the intent. The new assertion checks the property that matters (rule present, no script named) — the direction the assertion faces determines what a legitimate refactor costs you.
- **The behavioural test is what makes the rest trustworthy.** 397 baseline assertions plus 10 new ones is mostly structure; the one that commits into a scratch repo and reads the trailer back is the one that would catch a recurrence of bug 2.

## Recurring

- **Deletion lag in `bin/ainish-coder`.** A module removed in the previous session (`deploy_embed_provider_detect`, 2026-11-19) was still being called, so every `--rules` run emitted `command not found`. Worth checking for dangling callers whenever a source module is deleted — the failure surfaced as noise on a command that otherwise appeared to work.
- **Immutability flags hiding failed writes.** The `uchg`/444 contract files caused a rejected edit to look like a no-op rather than an error anyone noticed. This is the same class of silent-failure risk as the deploy-target bug above: both produced success-shaped output from a path that did not do its job.
