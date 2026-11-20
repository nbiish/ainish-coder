---
format: ainish/context-digest/v1
folder: suggestions
period: 2026-11
records_consolidated: 17
consolidated_at: 2026-11-20T22:57:51.548168+00:00
sources:
  - 2026-11-06-suggestions.txt
  - 2026-11-11-federation-gaps.md
  - 2026-11-11-tts-channel-retired.md
  - 2026-11-12-clap-bool-default-true-flags.md
  - 2026-11-12-generated-artifact-churn.md
  - 2026-11-12-large-context-retrieval-gap.md
  - 2026-11-12-nested-agents-secret-tree.md
  - 2026-11-12-rag-engine-authority-unstated.md
  - 2026-11-12-rules-signing-anchor-mismatch.txt
  - 2026-11-13-probe-conflates-reachability-with-auth.md
  - 2026-11-14-federation-machine-link.txt
  - 2026-11-14-local-router-fallback-models-fixes.md
  - 2026-11-14-machine-watch-operations.txt
  - 2026-11-17-19-context-priming-master.md
  - 2026-11-19-15-context-agent-followups.md
  - 2026-11-19-16-retire-rag-followups.md
  - 2026-11-20-15-identity-trailer-followups.md
---

# Digest — `.agents/suggestions`, 2026-11

This digest replaces 17 record(s) from 2026-11. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Partial digests

The merge step did not complete, so these 4 partial digests are kept as written. Each covers a different batch of the records named above.

## Accomplished

- **Restored the nine advisory masters** to `AGENTS.md` as dual-expertise pairs with an on-the-fly expert constitution; added `.agents/templates/masters.md` as the canonical definition, emitted the pairs inline in `context-packet.sh`, and fixed a dangling citation in `context-orchestration`. Backed by six assertions (all nine named, link resolves, no dangling citation, packet emits the block). The "nine core lenses" phrasing was retired, not aliased. (`2026-11-06-suggestions.txt`)
- **Built a retrieval-quality harness** (`bench`) with an nDCG/token/embedding-identity regression gate, committed a real baseline under a targeted gitignore exception, and fixed `bin/ainish-rag` exec'ing itself when its native binary was absent (which recursed silently across WSL, Git Bash, Linux, and the unknown-OS branch). The gate was exercised in all three states (pass / nDCG-fail / identity-changed-incomparable); `bench --regression` is the single reproducing command; the 2 Windows-only failures were proven pre-existing at pristine HEAD. Baseline names its embedding identity and engine commit. (`2026-11-06-suggestions.txt`)
- **Fixed a silent Obsidian-vault downgrade:** `ainish-rag wiki` from the Python engine stripped frontmatter, aliases, tags, and all `[[wikilinks]]`. `rag.py generate_wiki` now detects pages carrying the `ainish/wiki` tag and refuses (SystemExit with reason + correct command) instead of overwriting; non-vault repos still generate normally (verified both ways). Made `--index` opt-in in both engines. (`2026-11-12-generated-artifact-churn.md`)
- **Fixed the `wiki --index` flag** so it can be disabled (removed the clap `default_value_t = true`). (`2026-11-12-clap-bool-default-true-flags.md`, `2026-11-12-generated-artifact-churn.md`)
- **Retired the end-of-turn spoken-suggestion/TTS channel** (operator decision 2026-11-11). Removed the 564-line root transcript, the pack entry in `src/help.sh`, the TTS row/tree in `README.md`, the pack name in `llms.txt`, and all pack-name references outside the distribution folder. Kept the pack under `skills-to-distribute/`; its content now lives as ordinary `.agents/` context reachable via `ainish-rag --context`. (`2026-11-11-tts-channel-retired.md`)
- **Removed a self-peering WSL entry** (`windows-128gb`, same files as host at `/mnt/d/Code`) from the federation registry. (`2026-11-11-federation-gaps.md`)

## Unfinished

- **Six RAG subcommands still carry the clap `default_value_t = true` defect** (a bool+long flag that can only ever be true; no `--no-x`, and `--x false` is rejected). Remaining instances in `src/rag/src/main.rs`: `orient.inject`, `orient.task_conditioned`, `cleanup.compact`, `cleanup.prune_worktrees`, `gate.verify`, `monitor.once`. Only `orient.include_symbols` is genuinely configurable (it carries `action = clap::ArgAction::Set`). `orient.inject` is highest-priority — agent-facing, help says "(default: true)" but `--inject false` cannot be expressed, so injection silently stays on. Recommended fix (a): add `action = clap::ArgAction::Set` and accept `--flag true|false`. (`2026-11-12-clap-bool-default-true-flags.md`)
- **The vault/wiki generator is native-only (architectural split).** The renderer (frontmatter, `ainish/wiki` tag) exists only in the Rust crate; `rag.py`'s `generate_wiki` emits plain markdown. `bin/ainish-rag` routes plain invocations to Python and no `ainish-rag-{darwin,linux}`/`.exe` exists, so the reachable `wiki` is the one that cannot produce a vault. The fail-closed guard prevents damage but the split needs a decision — see `.agents/suggestions/2026-11-12-rag-engine-authority-unstated.md`. (`2026-11-12-generated-artifact-churn.md`)
- **`--machine-sync` two-lane divergence.** Verified live: WSL and Mac both committed on top of the same `f104102`, sync delivered each side's refs, but `main` stayed diverged while both peers reported `✓ synced`. Proposed fix belongs in `_ms_pull`: if peer `<branch>` is not an ancestor of `HEAD` and tree is clean, `git merge --no-edit <peer ref>`; on conflict, `git merge --abort` and report the lanes; skip dirty trees with a reason. Until then, check `git merge-base --is-ancestor <peer>/main HEAD`. (`2026-11-11-federation-gaps.md`)
- **Other federation/context gaps:** `--capture`-after-UI-edit is a habit, not enforced (proposed: `--machine-sync` refuse when repo chain ≠ live chain); `--context` still prints the embed-provider banner on graph-only runs (misreads as "spent embedding money"); Windows' embedding index is stale by construction (harmless under graph-first, warns every run until rebuilt); the router chain in `~/.config/local-router` is the one config that silently diverges. (`2026-11-11-federation-gaps.md`)
- **Bench corpus too small / native rebuild stale.** Only three saturated queries; expand before Phase 2. Mirror the harness into the Rust engine or rebuild `ainish-rag.exe` (stale since 2026-10-31) so launcher-driven runs report the new metrics. (`2026-11-06-suggestions.txt`)

## Insights

- **Documentation can degrade silently when the contract is refactored** — the nine lenses were removed from `AGENTS.md` while a skill kept citing them, and it survived weeks because nothing tested the wiring. The fix is a test, not a reminder. (`2026-11-06-suggestions.txt`)
- **A regression gate never seen to fail is not yet a gate** — the nDCG gate was validated in all three states before being trusted. (`2026-11-06-suggestions.txt`)
- **nDCG 2.131 (out of range) meant the metric definition was wrong, not the corpus** — normalize against retrieved reality and add a range assertion. (`2026-11-06-suggestions.txt`)
- **In clap 4, a `bool` field with `long` is a presence flag (`ArgAction::SetTrue`)**; adding `default_value_t = true` yields a flag that can only ever be true. The only test that distinguishes "declared" from "usable" is a `try_parse` round-trip asserting both polarities differ. (`2026-11-12-clap-bool-default-true-flags.md`)
- **Two engines answer `ainish-rag` but only one can produce a vault** — reachable default is Python (plain markdown), so any surface retrieval depends on (Obsidian `[[wikilinks]]`, frontmatter, tags) is silently downgraded unless the native path is used. (`2026-11-12-generated-artifact-churn.md`)
- **A launcher that execs itself recurses silently with no output and no exit** — found only because an unrelated bench run produced nothing. (`2026-11-06-suggestions.txt`)
- **A guest sharing its host's disk must not peer with its host** (realpath equality); a guaranteed-failure peer teaches the operator to ignore the peer list. (`2026-11-11-federation-gaps.md`)
- **The 120-line AGENTS.md gate is now the binding constraint** on documenting the context tool — worth a deliberate decision, not a silent trim each time. (`2026-11-11-federation-gaps.md`)
- **Move guidance into `.agents/` text, not generated transcripts** — the same content reaches an agent through retrieval with no synthesis, playback, or transcript-in-root dependency. (`2026-11-11-tts-channel-retired.md`)

## Recurring

- **Untested wiring/connectivity between components fails silently.** Appears as the retired nine-lens citation (survived weeks untested), the self-exec launcher recursion (silent, cross-platform), the Obsidian downgrade (silent overwrite of the retrieval surface), and the two-lane `--machine-sync` divergence (both peers report `✓ synced` while `main` diverged). The common lesson: absence of an error is not proof of correctness — assert polarity, ancestry, and state explicitly. (`2026-11-06-suggestions.txt`, `2026-11-11-federation-gaps.md`, `2026-11-12-generated-artifact-churn.md`)
- **Verify by reading back / exercising the failure, not by exit code.** The nDCG gate was validated across pass/fail/incomparable states; the Windows failures were proven pre-existing at pristine HEAD; both wiki fixes were verified both ways. A command exiting 0 (or `✓ synced`) is a claim, not proof. (`2026-11-06-suggestions.txt`, `2026-11-11-federation-gaps.md`, `2026-11-12-generated-artifact-churn.md`)
- **Config/behavior that silently diverges from the versioned repo.** The router chain in `~/.config/local-router`, the two-machine auto-commit lanes, and the stale Windows embedding index all reflect the same underlying risk: the live state drifts from what is committed, and the tool reports success regardless. (`2026-11-11-federation-gaps.md`)

---

## Accomplished
- **Nested `.agents/` secret-tree fix landed** (`2026-11-12-nested-agents-secret-tree.md`): `.gitignore` now ignores `src/rag/.agents/`, `skills-to-distribute/**/.agents/`, and `**/.agents/{rag,audit,wiki}/`, and the comms live-board pattern was widened to `*.live.{txt,md}`. Verified in both directions — the nested private-key path is ignored while the root `.agents/` stays tracked — and pinned by an assertion in `scripts/test-pqc-dist.sh`.
- **Vector/embedding retrieval path deleted** (`2026-11-12-large-context-retrieval-gap.md`): `retrieve_context` now returns `{"hits": [], "mode": "wiki_graph_empty", "notice": "..."}` with no embedding fallback, by operator decision.
- **`rag.py` refuses to touch vault pages** (`2026-11-12-rag-engine-authority-unstated.md`): the reachable Python engine was made to decline vault writes (option (c)) — correct but leaves `wiki` generation unusable from the default engine.

## Unfinished
- **Large-context replacement for the deleted vector path** (`2026-11-12-large-context-retrieval-gap.md`): only the deletion half shipped; the "use 1M-context models instead" half is unbuilt. Proposed `--context --deep` (LLM-directed file selection, option a) or naming likely directories on a miss (option b). Follow-on, not a defect.
- **Real fix for nested `.agents/` tree** (`2026-11-12-nested-agents-secret-tree.md`): only path-based ignores (symptom) landed. The engine still does not refuse to initialize an identity root outside the repository root it manages (option a), and there is no pre-commit scan for `.priv`/`.psk` regardless of path — the local scan did not flag `signer.mldsa65.priv`.
- **RAG engine authority split** (`2026-11-12-rag-engine-authority-unstated.md`): vault writer not ported into `rag.py` (option a, durable fix), and the native binary is never copied to `bin/` and no CI builds per-platform (option b). Pre-existing, architectural.
- **Rules signing anchor mismatch** (`2026-11-12-rules-signing-anchor-mismatch.txt`): `ainish-coder --rules` deploys correct content then fails at the signature gate — signer `69e7233dc7776273af28c3d80d774dad` vs anchor `d98405ea368484f51e64840d725343be` — so every `--rules` run on this host exits 1 until resolved. Resolution (set seed / rotate anchor / rebuild seed store) is an operator decision; anchor rotation is a security control. Consequence: signed `.agents/canonical/*` copies lag the edited `AGENTS.md` until one re-signing pass. Main-tree audit chain is uncommitted operator churn, untouched here.
- **Probe reachability/auth conflation** (`2026-11-13-probe-conflates-reachability-with-auth.md`): `secrets` still collapses catalogue reachability and auth readiness into up/down. Not fixed.

## Insights
- A graph miss (`wiki_graph_empty`) is the natural hand-off point to a large-context model reading files directly — one model call versus the deleted path's model download plus index build (`2026-11-12-large-context-retrieval-gap.md`).
- All `.gitignore` state rules were root-anchored; the engine writes `.agents/{rag,audit,wiki}` relative to the path it is given, so running from a subdirectory stages a private ML-DSA-65 key and session PSK. It was caught only by reading the staged-file list before commit (`2026-11-12-nested-agents-secret-tree.md`).
- `src/rag` ships two engines of different product generations: `bin/ainish-rag:69` hard-codes `PY_ONLY_SUBCOMMANDS=" context secrets "` to `rag.py`, no native binary exists, so the Rust vault renderer added in commit `788602f` (`wiki.rs`, +352) never runs on a standard host; `llms.txt:321,334` calling the pair Rust-primary is what misled a plan into scoping work to code that never answers a request (`2026-11-12-rag-engine-authority-unstated.md`).
- The signature gate failing closed on an unverifiable manifest is correct behavior, not a bug — the failure is the control working (`2026-11-12-rules-signing-anchor-mismatch.txt`).
- `probe_health` treats any non-401/403 as reachable; OpenRouter serves `/api/v1/models` publicly, so it reports `up` with no key while `/chat/completions` 401s. Measured 2026-11-13: openrouter up / zai down / xiaomi-mimo down, yet with the vault locked `resolve_driver_key` returned None for all three — every one would have skipped. "Up" means "endpoint answers," not "this step will work" (`2026-11-13-probe-conflates-reachability-with-auth.md`).

## Recurring
- **Symptom patches shipped, cause fixes deferred.** Nested-`.agents/` ignores landed but the engine still writes keys into the wrong tree; the vector path was deleted but its big-context replacement was not built. Both records name the deeper fix (option a) as the durable one and leave it open (`2026-11-12-nested-agents-secret-tree.md`, `2026-11-12-large-context-retrieval-gap.md`).
- **Misleading status or description causes real damage.** A green "up" on a step that cannot authenticate, and an `llms.txt` that calls the never-run Rust engine primary, each produce a wrong conclusion — one stops an operator looking, the other produced a wrong plan (`2026-11-13-probe-conflates-reachability-with-auth.md`, `2026-11-12-rag-engine-authority-unstated.md`).
- **Half-implemented decisions leaving the system in a split state.** Delete-embeddings-without-replacement; `rag.py` refusing vault pages while the vault renderer sits unreachable in Rust; canonical contracts lagging the edited `AGENTS.md` pending re-signing. Each is one decision with only its first half done (`2026-11-12-large-context-retrieval-gap.md`, `2026-11-12-rag-engine-authority-unstated.md`, `2026-11-12-rules-signing-anchor-mismatch.txt`).

---

## Accomplished

- **Mac preservation for the three-way `goal-first-trillion` split.** Both Mac tips were preserved as branches `preserve/mac-3c87fac` and `preserve/mac-dirty-tree` and delivered to the peer, so Mac-side work is not lost even though the histories remain unrelated (`2026-11-14-federation-machine-link.txt`).
- **Local-peer sync via `bash -c`.** `_ms_remote` was changed to run `bash -c` for local peers, which is what makes a local-peer sync work at all and matches the shape an ssh peer sees (`2026-11-14-federation-machine-link.txt`).
- **Transport fix enabling background sync.** `ssh localhost` is in place as the transport the watcher uses to reach repos macOS TCC blocks for a launchd agent; an install-time probe verifies the loopback key once (`2026-11-14-machine-watch-operations.txt`).
- **Non-streaming route classification exists and is correct in intent.** `classifyResponseContent` (`src/index.ts:6791`) classifies a 200 with no content and no tool calls as `instant_error`, and `isContentFailoverTrigger` (`:6838`) converts that into a failover; its doc comment already cites the 2026-11-09 empty-turn bug class (`2026-11-14-local-router-fallback-models-fixes.md`).
- **Partial fix for `skip_retrieval`.** A task that explicitly *names* a layer now forces retrieval (`2026-11-19-15-context-agent-followups.md`).
- **`--refresh-wiki` no longer hard-fails.** It falls back to the Python generator, which now emits vault format, is safe on any unsigned vault, and correctly refuses to splice the signed `ledger.md` (`2026-11-19-15-context-agent-followups.md`).
- **The digest itself records that "reviewed by the router" is now recoverable:** `ainish-rag` scrapes `responseModel` out of `pi`'s event stream (`2026-11-14-local-router-fallback-models-fixes.md`).

## Unfinished

- **`goal-first-trillion` convergence is a manual merge, not done.** Root commits `026b902` (Mac), `207d89e` (Windows), `39005a8` (origin) share no ancestor; only 3 paths are common and all 3 differ. Origin is newest (45 commits / 132 files), Mac holds `analysis/income-ledger.md` and `orchestration/crew-roster.md`, Windows holds `src/*.ts` (the Gumroad API). `--machine-sync` cannot fast-forward unrelated histories, so actual convergence is a manual merge against `origin/main` (`2026-11-14-federation-machine-link.txt`).
- **Windows `machines.txt` points the Mac peer at the wrong root.** It maps `mac-18gb=mac-18gb:/Users/nbiish/code`, but the Mac copy lives under a removable-volume code root. `--machine-link` fixes it per repo; a corrected code root in the registry fixes it for every repo (`2026-11-14-federation-machine-link.txt`).
- **No debounce for `post-commit`/`post-merge` hook sends.** Bounded (`ConnectTimeout`, `|| true`) and cannot block a commit, but rebase/amend loops and many-small-commit repos spend real ssh time. Proposed fix: a minimum-interval stamp in `.git/ainish-machine-sync.stamp` (`2026-11-14-federation-machine-link.txt`).
- **`bash -c` local-peer assumption unverified for a local Windows checkout addressed as a plain path** (not through WSL); `bash -c` will not exist there. Theoretical today; re-check if local Windows peers appear (`2026-11-14-federation-machine-link.txt`).
- **`--machine-sync --all` is sequential**, so a slow peer serialises every repo behind it. Parallelising would speed it up and also make output unreadable; suggested shape is per-repo logs plus a summary (`2026-11-14-federation-machine-link.txt`).
- **Local-router defects D1–D4 not fixed.**
  - D1 (blocking): a 0-block 200 is accepted under streaming. Observed `pi --print --mode json --model local-router/fallback-models "Say OK"` returning `content: []`, `usage.output: 1`, `stopReason: "stop"` — 14/15 times in one window, 0/12 in a later one, so it is chain-order, not one code bug. Two gaps: the classifier only runs for non-streaming JSON (`src/index.ts:7531`, gated on `!isStreamRequest && isJsonResponse`), and `choices: []` returns `'generated'` (`:6809`) instead of `instant_error`. Fix: classify `choices.length === 0` as `instant_error` and classify the accumulated stream body (buffer first chunks or classify on `[DONE]`).
  - D2 (blocking): the 16-step `fallback-models` chain leads with free preview `openrouter-ernie-5.5-flash-preview-free`, with paid `zai-glm-5.3-flash` (operator's preferred direct fallback) at step 5; measured one-word answers 0.9s–10.3s. Operator decision: reorder to `zai-glm-5.3-flash` → `xiaomi-mimo-mimo-v2.6-pro` → `cursor-deepseek-v41-flash-1017` → `openrouter-deepseek-v4.1-flash-1017-batch`, free previews last — a `fallback-models.json` change, not code.
  - D3 (high): the non-streaming success path rewrites `model` to the presented name and exposes no route/step/timing; `attemptLog` and `trajectory` are built (`:8360`, `:8475+`) but only reachable via log/UI. Proposed fix: headers `x-local-router-route`, `-step`, `-model`, `-attempts`, `-ms`.
  - D4 (medium): `:8398` returns HTTP 400 for `no_reasoning_models`, which reads to a client as a caller error; should be 409/503.
- **Context-priming learning is research-only; no code written.** Status line says "research complete, implementation not started" (`2026-11-17-19-context-priming-master.md`).
- **Compiled renderer stale** (below), and **five context-agent follow-ups left open** — improver evidence, skip-routed measurement, `--rules` git guard, orphaned shas, and the rebuild itself (`2026-11-19-15-context-agent-followups.md`).

## Insights

- **`ainish-rag --context` runs its two EGM reviewer roles as `pi` agents against `model: "local-router/fallback-models"` on `http://127.0.0.1:11434`.** A failure in that route is indistinguishable from the model having nothing to say, so the context tool silently produces a prime with a missing role — the worst failure shape for this tool (`2026-11-14-local-router-fallback-models-fixes.md`).
- **`src/rag/rag.py` has no per-repo learning path.** Every retrieval constant is a hand-set module literal: `GRAPH_MAX_WIKI_PAGES = 8`, `GRAPH_MAX_ARTIFACTS = 2`, `GRAPH_CHAPTER_CHARS = 1400`, `GRAPH_HOP_BONUS = 0.35` (`rag.py:3591–3594`); `0.55 + 0.45 × recency` (`:3857`); `len(shared) >= 3` edge threshold (`:3787`); `CONTEXT_SECTION_CAPS` 12/54/20/14 % (`:3489`). Nothing compares two variants, and `evaluate_context_sufficiency()` scores retrieval hits, not the injection (`2026-11-17-19-context-priming-master.md`).
- **Harness² constraints (arXiv 2610.14224, `google-research/harness2`):** refining a harness without a reference execution and a library is a regression (Code 73.4 → 63.2, Web 69.9 → 65.0), so a generation-0 baseline is mandatory; ablations all earn their place (library −3.1/−1.8, scoped editors −2.9/−3.7, composition −1.6/−1.9). Practitioner evidence adds self-bloat (a growing `before_done` checklist ate 100% of savings by task 5), re-verification loops, and criterion leakage; round 1's elegant recursive harness *matched* a frozen three-tool harness exactly — recursion pays only when capability is expensive to rebuild, tasks repeat in a domain family, and the harness stays lean. Proposed shape: a `PrimeProfile` of bounded scalars and short token lists (no prose, no code) at `.agents/context-harness/prime-profile.json`, tracked unlike `.agents/rag/`; learning is a separate opt-in verb `--context-learn`; `--context` only reads the profile; generation 0 written idempotently by `ainish-coder --rules`; acceptance is a deterministic gate over five mechanical signals with `KEEP_BASE` as a first-class outcome, possibly the most common one. **Phase 0 is a throwaway experiment to test whether the five signals separate profiles at all — if not, do not build it (~800 lines).**
- **Two binaries can serve the same plist.** The launchd agent records an absolute `bin/ainish-coder` path at install time; installing from a worktree records the worktree path, and removing the worktree silently breaks the daemon — observed live, log filled with `no such file or directory: .../watch-ssh-transport/bin/ainish-coder`. Installer should detect a worktree-local CLI (`git rev-parse --git-common-dir` vs `--git-dir`) and refuse, or prefer a stable installed path (`2026-11-14-machine-watch-operations.txt`).
- **`ssh localhost` is a load-bearing, unverified dependency.** It works because the loopback key is authorized, but nothing re-checks; a rotated key or disabled `sshd` fails every cycle with a permission error that looks like a repo problem (`2026-11-14-machine-watch-operations.txt`).
- **The watcher is timer-based, not event-based** — no `fswatch`/`inotifywait` on this host, so latency is 2s poll + 2s debounce. Correct, just not fast (`2026-11-14-machine-watch-operations.txt`).
- **The compiled `wiki` renderer demands a retired model.** `src/rag/target/release/ainish-rag wiki` exits 1 with `EmbeddingGemma GGUF model not found in <hf-cache-root>`; the binary predates the 2026-11-12 retirement, so the native vault path is unusable even though `native_renderer()` discovers it correctly. Settled by rebuilding after removing the embedding-model requirement from the `wiki` verb; meanwhile `AINISH_VAULT_RENDERER` can point at a known-good build (`2026-11-19-15-context-agent-followups.md`).
- **`--rules` seeding is gated on a git repository** (`bin/ainish-coder:316`, `-d "${target_dir}/.git"`) because the outcome signal needs commit history — so a repo initialized later never gets a frozen baseline (`2026-11-19-15-context-agent-followups.md`).
- **Historical task records name shas absent from history** (four records): history was rebased across machines, so the commits are gone and corroboration is reported rather than required (`2026-11-19-15-context-agent-followups.md`).
- **The federation task established that an unadvertised capability is dead capability** — hence the context-priming note exists purely as a discoverability surface until implementation starts (`2026-11-17-19-context-priming-master.md`).

## Recurring

- **Unrelated histories are the root of every federation symptom.** The three-repository split of `goal-first-trillion`, the wrong `machines.txt` code root, and the impossibility of a `--machine-sync` fast-forward all stem from one cause: a fleet can believe it is synced while running two different projects (`2026-11-14-federation-machine-link.txt`).
- **Silent or misleading success from a router/cache layer.** D1's 0-block 200 accepted as a turn, D4's 400 for a server capability gap, D3's lack of which-step/latency visibility, and D2's free tier leading the chain are all the same failure shape — a wrong answer that looks like a right one (`2026-11-14-local-router-fallback-models-fixes.md`). The daemon breaking silently after a worktree is removed and the stale renderer failing the vault path belong to the same family (`2026-11-14-machine-watch-operations.txt`, `2026-11-19-15-context-agent-followups.md`).
- **"One command answers everything" still has holes.** `skip_retrieval` is reachable for tasks that describe work without naming a layer, `--rules` silently skips a non-git target, and the context-priming research is unfixed precisely because `--context` has no learnable state — three gaps in the same promise (`2026-11-19-15-context-agent-followups.md`, `2026-11-17-19-context-priming-master.md`).
- **Measurement is the missing prerequisite for fixing.** `skip_retrieval` usage is uncollected; context-priming's five signals may not separate at all; D3's timing is unobservable from the response; the improver's repetition is unevidenced. In each case the record names a number that must be measured before any code lands (`2026-11-19-15-context-agent-followups.md`, `2026-11-14-local-router-fallback-models-fixes.md`, `2026-11-17-19-context-priming-master.md`).

---

## Accomplished

- The RAG retirement itself landed; these files are its follow-ups. The tool is now `ainish-coder` (`--context`), and the schema/env/shim remnants below are what the retirement left behind (`2026-11-19-16-retire-rag-followups.md`).
- `AINISH_MLDSA65_SEED` is already renamed to the new prefix — the only env var in that family already migrated (`2026-11-19-16-retire-rag-followups.md`, item 2).
- Identity-trailer work landed on `origin/main..main` only (operator decision): a history rewrite removed harness `Co-authored-by:` trailers from that range, leaving the author field correct on most commits (`2026-11-20-15-identity-trailer-followups.md`, item 1).
- Supporting tooling exists and works: `scripts/strip-harness-trailers.sh`, the `scripts/harness-attribution.txt` table, `--rules` (installs a `commit-msg` block), `--rules-doctor` (checks the rules-sync block), a guard with a generic `bot_email_pattern` that catches tool-shaped authors, and `deploy_rules_sync.sh` (`2026-11-20-15-identity-trailer-followups.md`, items 2–4).

## Unfinished

All eight items are identified with a settled-by plan but not yet executed.

From `2026-11-19-16-retire-rag-followups.md`:
1. On-disk schema strings (`ainish-rag/prime-profile/v1`, `ainish-rag/context-harness-status/v1`, `ainish-rag/context-harness-autolearn/v1`, `ainish-rag/mldsa65-envelope/v1`, etc.) still carry the old prefix in files already held by this and deployed repos. Plan: add a `format`-aliasing reader accepting either prefix, then bump the writer in one deliberate release.
2. `AINISH_RAG_*` env vars (`AINISH_RAG_DRIVER_MODEL`, `AINISH_RAG_GOLDFISH_MODEL`, `AINISH_RAG_ALLOW_SELF_REVIEW`, and others) still read on every call and named in deployed rules. Plan: read `AINISH_CONTEXT_*` first, fall back to `AINISH_RAG_*` with a one-line deprecation notice, remove the fallback after a release.
3. `skills-to-distribute/skills/typesafe-jev/references/rag-decision-catalog.md` has current content but a stale RAG-era filename. Plan: rename to `decision-catalog.md` and update the pack's `llms.txt` index in one edit (safe — distributed file, not signed).
4. `bin/ainish-rag` shim still exists for old deployed `AGENTS.md` files and prints a deprecation line. Plan: check `.agents/ainish-sync.json` in real deploy targets; delete the shim once none name `ainish-rag`.

From `2026-11-20-15-identity-trailer-followups.md`:
1. Pushed history still carries 62 `Co-authored-by: Cursor` trailers (`git log --all`); the rewrite covered `origin/main..main` only. Plan: decide once on a force-push window or leave them (cosmetic now that authors are correct).
2. The attribution table is referenced, not copied, into deployed repos — `--rules` points at the SOURCE install's `strip-harness-trailers.sh`, so targets run the source's table. Plan: decide whether a self-contained target should carry its own copy; if so, have `deploy_rules_sync.sh` write script + table into `.agents/bin/`.
3. `--rules-doctor` checks the rules-sync block but not the identity blocks, so a target missing its `commit-msg` hook reports healthy. Plan: add the two block markers (already stable and unique) to the doctor's check list.
4. No trailer equivalent of `bot_email_pattern`: a harness absent from `harness-attribution.txt` has its trailers passed over. Plan: watch history post-ship; add one line to the table if a new product appears.

## Insights

- A schema string written into files is a data migration with a compatibility window, not a rename — the prefix functions as a schema name, not a product name (`2026-11-19-16-retire-rag-followups.md`, item 1).
- Env vars named in deployed rules cannot be renamed silently: doing so would disable an operator's pins on upgrade, hence the read-new/fallback-old pattern (item 2).
- Distributed files are safe to rename in one edit; signed artifacts are not — that distinction decides item 3's approach.
- The `bin/ainish-rag` shim exists purely for backward compatibility; `.agents/ainish-sync.json` in a deploy target is the record of whether it is still needed (item 4).
- Referencing the source install's script (rather than copying it) is correct for a shared fleet but wrong for a self-contained target (`2026-11-20-15-identity-trailer-followups.md`, item 2).
- Trailers are cosmetic once the author field is correct; the author field is what actually matters (item 1).
- The guard covers authors but not trailers — two different attribution surfaces needing two different mechanisms (item 4).
- The attribution table is deliberately the extension point: a new harness is one line in `harness-attribution.txt` (item 4).

## Recurring

- Both files are follow-ups to a completed breaking change (RAG retirement; identity-trailer rewrite), and both leave a long tail of small deferred items rather than finishing the migration in one pass.
- A consistent settle-by philosophy in `2026-11-19-16-retire-rag-followups.md`: add a compatibility alias/fallback first (aliasing reader, env fallback, compat shim), remove it only after a release — never rename or delete silently.
- A recurring "deploy target vs source install" concern across both files: schema strings and the shim live in deployed repos (file 1, items 1/2/4), and the attribution table/script are referenced from the source install into targets (file 2, item 2).
- A recurring theme of batching cleanup decisions to be made "once, not per-commit/per-item" — the force-push decision (file 2, item 1) and the watch-then-extend approach for unknown harnesses (file 2, item 4).
