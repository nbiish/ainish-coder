---
format: ainish/context-digest/v1
folder: comms
period: 2026-11
records_consolidated: 5
consolidated_at: 2026-11-20T22:09:47.740018+00:00
sources:
  - 2026-11-05-team.txt
  - 2026-11-06-team.txt
  - 2026-11-07-team.txt
  - 2026-11-08-team.txt
  - 2026-11-10-team.txt
---

# Digest — `.agents/comms`, 2026-11

This digest replaces 5 record(s) from 2026-11. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Accomplished

- **Skills-selection selector restored and hardened** (`2026-11-05-team.txt`, branch `fix/rules-skill-selection`): re-added per-repo skill-pack selection that `--rules` had lost. Ask-once-per-repo on first contact, plus `--select-skills [DIR]` and `--skills-list [DIR] [--json]`; bounded idle read with cancel/timeout falling back to the saved selection; additive env vars `AINISH_SKILLS_PROMPT`, `AINISH_SKILLS_PROMPT_TIMEOUT`. Verified: `scripts/test-pqc-dist.sh` 14/14 selection assertions, pty smoke 17/17, ainish-rag audit verify 16/16, 27 canonical contract transitions.
- **Two defects fixed in the same session** (`2026-11-05-team.txt`): engine invocations now detach stdin, fixing the WSL `SIGTTIN` hang (root cause: inherited pty stdin + non-foreground process group stops the `.exe`, dragging `timeout` down so the watchdog never fired); `--pqc-install` no longer false-negatives on fresh installs — success is launcher installed plus usable identity (`generated`/`present`/`failed`), not `bundleExists`, which `keygen` never writes. `pqc-install/v1` JSON gained a `present` keygen state. Verified: 51/51 test-pqc-dist, real-engine pty smoke 21/21 with `--rules` now 6–8s exit 0 where it previously hung.
- **Signer preflight moved before any artifact write** (`2026-11-06-team.txt`, main): a clone now fails fast instead of leaving a manifest with no signature, armed hooks, and no enrollment. Test/sandbox cleared and its stale fleet entry unenrolled. Verified: real clone reproduced the half-deployed state pre-fix and refuses cleanly after; test-pqc-dist 62/62; audit verify 16/16; fleet 2/2 CURRENT.
- **Nine dual-expertise "masters" lenses re-issued** (`2026-11-06-team.txt`, docs): nine `masters of ___/___` niches with one distinct question each, canonical definitions in `.agents/templates/masters.md` (constitution/omission/recording), packet emission, and a dangling citation to the removed "nine core lenses" fixed. Six new assertions. Verified: 73/73; contract re-signed; audit verify 16/16. The old phrase is retired, not aliased.
- **RAG Phase 0 benchmark baseline landed** (`2026-11-06-team.txt`, `feat/rag-phase-0-bench-baseline` → main): a measured floor before any retrieval change. `bench` now records nDCG@3, per-query chunk tokens, embedding identity, store row count, engine commit; `--regression` reports a changed embedding identity as *incomparable* rather than a false regression; baseline committed via a targeted `.gitignore` exception (narrowed from directory ignore to contents glob); `bin/ainish-rag` no longer execs itself. Baseline format `ainish-rag/bench-baseline/v2`; v1 baselines still compare on recall alone. Verified: 71 python tests (18 new); full-corpus Recall@3 1.000, nDCG@3 1.000, 920 avg chunk tokens, 3627 records, `api:openrouter:openai/text-embedding-3-small` at `fab34e1`; `--version` returns under WSL and Git Bash (previously hung).
- **Four cross-platform PQC defects fixed** (`2026-11-06-team.txt`, main): (1) Windows could not see the WSL store — `wsl.exe` output was decoded unconditionally as UTF-16-LE but this build emits UTF-8, mojibaking distro names so the interop probe always failed; encoding is now detected from byte shape and both `wsl.localhost` and legacy `wsl$` shares are tried. (2) Gate isolation used `HOME=` only, which Windows Python ignores, so the hermetic test touched the operator's real keypair and reported `present` instead of `generated`; `PQC_SECRETS_DIR` + `USERPROFILE` now pin the sandbox. (3) A stamp assertion hardcoded the WSL path form, failing on a correct translator under Git Bash, with no native-POSIX branch. (4) The whole gate exited 0 with SKIP when `uv` was absent, so CI read it as a pass; it now fails closed, with `AINISH_ALLOW_GATE_SKIP=1` as a new opt-in escape hatch. Verified: Git Bash 73/73 (was 71/73), WSL 73/73, `ubuntu:24.04` Docker with real uv 73/73, Linux without uv exits 1 with guidance, native-POSIX stamp translation verified in alpine, Windows reports 13 keys.
- **Context-injection system wired to AGENTS.md** (`2026-11-07-team.txt`, `feat/rag-context-injection`): one `ainish-rag` call returns a budgeted, labelled injection combining Elephant and Goldfish sections, tiered `local-router → openrouter → zenmux → local-model` with a genuine offline floor. AGENTS.md lost the clause that made the pipeline unreachable and gained the `<CONTEXT_INJECTION>` section; new `DriverEngine` with source/model_verified/attempts reporting; `elephant_synthesize` / `goldfish_review`; `assemble_injection` applies a fixed degradation ladder; `context` subcommand, completions, and a secrets driver table. Phase 4 marked done with measured numbers and its latency limit stated.
- **Plans became a first-class `.agents` surface** (`2026-11-08-team.txt`, `feat/agents-plans-artifact`): question-me now compiles a durable plan at `.agents/plans/{date}-{slug}.plan.md` holding the agent's plan, the clarification ledger, and derived todos. New `.agents/templates/plan.md` (frontmatter contract + 7 fixed sections) and `.agents/plans/llms.txt`; question-me rewritten (pillar 6, Phase 0 opens the plan, Phase 2 logs each decision to section 4 before asking the next, Phase 3 derives section 5 todos and locks status); new `references/plan-artifacts.md`; deploy wiring in `bin/ainish-coder`, `deploy_agents.sh`, `deploy_skills.sh`, `verify_skills.sh`; `render_orientation_section` reports newest plan status and open-todo count via a stdlib-only frontmatter reader; `context-packet.sh` gained a matching `plan_state` section. Contract now names `.agents/plans/`.
- **macOS/Windows rules revision converged** (`2026-11-10-team.txt`, `chore/machine-sync-20261110`): macOS main fast-forwarded `d045363..c5bf68e` (Windows commit "fix(rules): stop shipping bytecode caches, and make the manifest describe reality") and pushed to origin so Windows needs no pull. Verified: mac HEAD = origin/main = Windows HEAD = `c5bf68e`, 389 tracked files both sides, gate parity 153 pass / 14 fail with the same 14 pre-existing failures reproduced at a `d045363` baseline worktree (zero regressions).

## Unfinished

- **RAG context injection is still `in-progress`** (`2026-11-07-team.txt`): the entry records blockers `none` but status `in-progress`, not `merged`. Consequences noted there and not yet resolved: the canonical contract was re-signed (ML-DSA-65, 33 hash-chained transitions), so any target comparing its AGENTS.md to the root copy reports drift until refreshed. The record is also truncated mid-word in the compat field ("New CL"), so its full compat/rollback note is not recoverable from this digest.
- **The plans artifact work is `verifying`, not done** (`2026-11-08-team.txt`, `feat/agents-plans-artifact`). Compat: question-me no longer writes to `.agents/tasks/{date}-question-me-{slug}.md`; it writes the plan and creates the task record at the path its frontmatter names. AGENTS.md's "Do not create plan…" line was being changed — the sentence is cut off in the source.
- **Windows has an uncommitted work lane** (`2026-11-10-team.txt` findings): `D:\Code\ainish-coder-context-prime` on `feat/agents-context-prime` — 13 files, +4184/−2361 under `src/rag`, plus 8 new test scripts, a plan, and a task record. Not synced because uncommitted work has no transport; it needs a commit on its branch. **This is the only copy of the Rust `PY_ONLY_SUBCOMMANDS` redirect that makes the mandatory `ainish-rag --context` work on Windows**, where PATH resolves the stale `bin\ainish-rag.exe` before the `.cmd` launcher. Losing this worktree loses that fix.
- **14 PQC-environment test failures are a standing baseline**, not fixed (`2026-11-10-team.txt`): the gate reports 153 pass / 14 fail, and the same 14 reproduce at `d045363`. Nothing in this period closed them.
- **Two Windows-only test-pqc-dist failures** (`2026-11-06-team.txt`, bench entry): reproduced at pristine HEAD, i.e. pre-existing, and not addressed.

## Insights

- **The WSL hang was a process-group problem, not a timeout problem.** A watchdog built on `timeout` cannot fire when the child it supervises is stopped (`2026-11-05-team.txt`). Detaching stdin from engine invocations fixed it; `--rules` went from hanging to 6–8s exit 0.
- **`wsl.exe` output encoding is not fixed across builds.** Assuming UTF-16-LE produced mojibake distro names, which silently disabled Windows→WSL store interop (`2026-11-06-team.txt`). Detect from byte shape; try both `wsl.localhost` and legacy `wsl$`.
- **`HOME=` is not an isolation boundary on Windows Python.** A "hermetic" test reached the operator's real keypair and passed with the wrong verdict (`present` vs `generated`, `2026-11-06-team.txt`). Pin `PQC_SECRETS_DIR` and `USERPROFILE`.
- **A skipped gate is indistinguishable from a passing gate in CI.** `exit 0` on missing `uv` read as green (`2026-11-06-team.txt`). Fail closed; keep an explicit, named opt-in escape hatch.
- **`bundleExists` is the wrong success predicate for `keygen`** — `keygen` never writes a bundle, so a correct fresh install reported failure (`2026-11-05-team.txt`).
- **The embedding identity must gate benchmark comparability.** Comparing metrics across a changed embedding model yields false regressions; the engine now reports "incomparable" instead (`2026-11-06-team.txt`).
- **Removing a concept from the contract without removing its citations breaks skills silently.** Nine lenses were deleted from AGENTS.md while a skill still cited them (`2026-11-06-team.txt`); re-issuing them as masters fixed the dangling reference.
- **Uncommitted work cannot be federated.** The one artifact the Windows host uniquely holds is the one artifact that never crossed machines (`2026-11-10-team.txt`).
- **Records in this period are truncated by the ledger writer.** Several entries (11-05, 11-06, 11-07, 11-08, 11-10) cut off mid-field, so verification counts and compat notes for those entries are incomplete here. Treat the git history as authoritative for anything load-bearing.

## Recurring

- **Cross-platform defects are the dominant theme.** The same day produced three independent platform failures — WSL `SIGTTIN` (`2026-11-05-team.txt`), UTF-16 vs UTF-8 `wsl.exe` decoding and `HOME=` isolation (`2026-11-06-team.txt`), Git Bash path-form assertions (`2026-11-06-team.txt`) — and the cross-machine sync (`2026-11-10-team.txt`) exists to hold one revision steady across mac, Windows, and WSL. Any new path, encoding, or environment-variable handling should be assumed platform-dependent until tested on all three.
- **"Verify by reading back" appears as a repeated practice, not a slogan.** Real clone reproduction before and after the signer fix (`2026-11-06-team.txt`); three-surface `git rev-parse` comparison for the sync (`2026-11-10-team.txt`); a detached worktree at `d045363` to prove the 14 failures were pre-existing rather than introduced (`2026-11-10-team.txt`).
- **Fail-closed corrections recur.** The gate that exited 0 on missing `uv` (`2026-11-06-team.txt`), `--pqc-install` false-negativing on a correct fresh install (`2026-11-05-team.txt`), and the signer preflight ordering (`2026-11-06-team.txt`) are three instances of the same lesson: a control that cannot distinguish success from absence is worse than one that refuses.
- **Contract changes force fleet-wide drift, every time.** Re-signing the canonical contract for the masters re-issue (`2026-11-06-team.txt`) and again for context injection (`2026-11-07-team.txt`) and again for plans (`2026-11-08-team.txt`) each left targets reporting drift until their next rules refresh. Contract edits should be batched where possible; each one has a fleet cost.
- **Test-count growth tracks each change, with a persistent unaddressed baseline.** 14/14 → 51/51 → 62/62 → 73/73 → 153/14 across the period (`2026-11-05` through `2026-11-10`), while the 14 PQC-environment failures survived every one of those runs untouched.

## Review

The draft is incomplete — it cuts off mid-sentence in **Insights** ("The WSL hang was a process-group problem") and has **no Recurring section at all**. As delivered it does not satisfy the four-section requirement; a reader gets Accomplished and Unfinished but loses whatever the Insights/Recurring synthesis was meant to carry.

Omissions a future reader would miss:

- **The entire second 2026-11-10 entry is dropped** (`2026-11-10-team.txt`): `[2026-11-10T18:20:00Z] feat | branch:feat/machine-sync | start:16:20 end:18:20`. The source truncates its output at "sco…", so its substance is partly unrecoverable, but the digest doesn't even record that this two-hour `feat/machine-sync` branch existed. That it followed the same-day `chore/machine-sync` is exactly the kind of recurrence the digest is supposed to surface.
- **The `nosecrets` line** (`2026-11-10` sync): "no secrets crossed the wire; the bundle carried one commit of tracked source only; `bin/*.exe` and `.agents/rag` index state stayed machine-local by design." This is a checkable safety fact and is absent.
- Minor verification details dropped: `set -euo pipefail` edge cases and "canonical byte identity" (11-05 selector entry); "2/2 verified" on the fleet (11-06 signer entry). Small, but the digest claims to preserve checkable specifics.

Unsupported / imprecise:

- Digest says "**27 canonical contract transitions**"; source says "**contract history 27 transitions**." Supported, just reworded — fine.
- The Insights fragment "process-group problem" is *supported* (source root-causes it to inherited pty stdin + non-foreground process group), so no fabrication there — it's just unfinished.

Everything in Accomplished and Unfinished is faithful to the sources; the truncations in the source records (11-05 "`--r…`", 11-07 "New CL", 11-08 "Do not create plannin…") are honestly flagged in the draft rather than invented around. The failover line appended after the draft is a runtime event, not digest content, and is correctly not part of the review.
