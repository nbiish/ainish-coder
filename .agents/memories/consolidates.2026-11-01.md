---
format: ainish/context-digest/v1
schema: consolidates.{naming}.md
folder: memories
period: 2026-11+
records_consolidated: 16
consolidated_at: 2026-11-27T00:01:05.896052+00:00
profiles: [consolidate-elephant, consolidate-structural, consolidate-archivist, consolidate-goldfish]
transports: [hermes]
sources:
  - DIGEST-memories-01.md
  - DIGEST-memories-2026-09.md
  - DIGEST-memories-2026-10.md
  - DIGEST-memories-2026-11.md
  - 2026-11-01-memory.txt
  - 2026-11-04-memory.txt
  - 2026-11-05-memory.txt
  - 2026-11-06-memory.txt
  - 2026-11-19-memory.txt
  - 2026-11-20-memory.txt
  - 2026-11-21-memory.txt
  - 2026-11-22-memory.txt
  - 2026-11-23-memory.txt
  - 2026-11-25-12-memory.md
  - 2026-11-25-13-memory.md
  - 2026-11-25-memory.txt
---

# Digest — `.agents/memories`, 2026-11+

This digest replaces 16 record(s) from 2026-11+. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
# Digest — .agents/memories, 2026-11+ (merged from partial digests 1–5; supersedes them)

The 2026-11+ window (with 2026-09/10 carry-forward) carried ainish-rag from multi-round build-out through vector-subsystem deletion and collapse into one Python context engine behind `ainish-coder --context`, hardened the Elephant/Goldfish review onto pi agents, unified pack/surface/license governance under gates, and stood up a PQC-signed federation feed — with the EGM split, the direct-transport chain, and the signing-anchor rotation still unmeasured or unlanded.

## Accomplished

- Memory cutover to dated {date}-memory.txt / {date}-suggestions.txt under format law AGENTS.md <REPO_MEMORY>; repo-memory-graph doctrine, GitNexus and the memorix/reference_memory/engram MCP plane removed outright; portable SHA-256 chain (sha256sum→shasum→openssl→python3→python→powershell→cksum), portable git hooks (while-read, not xargs -r), Darwin chmod/uchg ordering fixed (2026-09-23-memory.txt).
- ainish-rag built and hardened through rounds 1–14, each shipping a native bin/ainish-rag.exe and passing bin/security_gate.py + ainish-rag gate: living wiki, Jev two-stage rerank, loopback PSK, DP budget ledger, ML-DSA-65 receipts, in-toto, Trojan-Source rejection, Zero-Trust row, gate --strict; round 14's record is truncated mid-list (DIGEST-memories-2026-10.md, DIGEST-memories-2026-11.md).
- Embedding/decision plumbing: provider.rs resolution keeps keys off disk; OpenRouter/ZenMux /embeddings verified live; DecisionEngine on the OpenRouter Decisions API with a local-router fallback that never receives the OpenRouter key; Local Router 1.1.0 verified as a typed decisions transport (61467cf); typesafe-jev skill pack passes security_gate.py (DIGEST-memories-2026-10.md).
- Coordination split: plan owns reasoning + checkboxes, task owns coordination via one plan: line; naming scheme {date}-{HH}-{slug}.md with a shared mtime-based resolver in rag.py mirrored in the crate; comms stays one ledger per UTC day (DIGEST-memories-2026-11.md).
- Obsidian vault/RAG contract: reader changed before writer ([[wikilinks]] with skip list and fence/code stripping), ainish-rag wiki signs only when the envelope fails verify, generate_wiki REFUSES on ainish/wiki-tagged pages, vault pages derive project name from origin/canonical root, generation via the native binary (DIGEST-memories-2026-11.md).
- Vector subsystem deleted 2026-11-12 (embed/store/ingest, lancedb/arrow crates, 10 verbs; retired verbs parse, print replacement, exit 1); supersedes the 2026-10 LanceDB/vector material; provider.rs and the decision layer were not recorded removed (DIGEST-memories-2026-11.md).
- Pack governance: pqc-secrets exclusion fixed with two predicates + one shared list consulted by deploy/verify/status/sync; four security packs consolidated to one; retirements swept same-commit with a no-live-surface gate; README doc-drift gate added; _skill_mandatory single predicate asked by every surface, _skill_channel_excluded removed, stale --skills-sync honoured-off fixed; security-first-agent retired into AGENTS.md posture, contract gate raised 120→160 (2026-11-07-memory.txt; DIGEST-memories-2026-11.md).
- Skill payload/target split via AINISH_SKILLS_[SOURCE|TARGET]_REL; _PQC_ENGINE_REL split into side-named constants with legacy fallback (DIGEST-memories-2026-11.md).
- Surface rules consolidated into src/rag/master-surfaces.json (both engines load it; compat:/budget: declarations gated with why-fired cards); route returns context_budget_tokens 0–3600 + next_action; orient --inject caps sections at budget/12/sections; gate state GREEN 77.4% STRONG_ANCHOR, canonical e3c72db6… (2026-11-01-memory.txt).
- context-orchestration skill separates durable Elephant design from ephemeral packets; bin/context-packet.sh --mode goldfish excludes memory/COMMS/implementation context; bin/egm-check.sh fails closed; always-on contract routes context through it, optional skills on demand; ainish-rag rescoped to operator utility (2026-11-04, 2026-11-05-memory.txt).
- Retrieval wired into the contract: the AGENTS.md "not an agent intake requirement" sentence removed and every "operator utility, not agent intake" phrasing rewritten in the same commit (2026-11-07-memory.txt).
- Elephant/Goldfish review built and hardened: goldfish_review(driver, task, retrieval_text, elephant_text, token_cap) isolation signature; a stray elif deletion fixed by asserting child stdout parses as JSON; ainish-rag --context argv normalisation; reviewer independence settled (--no-session structural fresh-context, --goldfish-model pin, distinct_models: false + "SAME MODEL" line, describe-don't-condemn reporting) (2026-11-07-memory.txt, 2026-11-14-00-memory.md).
- Driver chain shaped per consumer in DRIVER_CHAIN with expect_any fallback; four DIRECT transports recorded by 2026-11-13; Nous Portal/Nebius/ZenMux out of the default chain (2026-11-07-memory.txt, 2026-11-14-00-memory.md).
- EGM roles moved onto pi agents: pi --print --no-session --no-tools --mode json --thinking <level> --model <id> --append-system-prompt <brief> @file…; PI_MODEL_IDS translation; pi_agent_call one retry + attempts_made; served_model capture; AINISH_RAG_PI_TIMEOUT 90s; both roles --thinking off (2026-11-14-00-memory.md).
- AGENTS.md cut 208→90 lines behind a where-to-look table with length as a gate assertion; later contract internals removed to 159/160, prompt-governance + canonical-license rules at 159/160, Parallel Work & Integration PR-inspection reminders at 158/160, Git & Pull Request Protocol added (2026-11-07-memory.txt; 2026-11-20, 2026-11-22, 2026-11-23, 2026-11-25-13 records).
- WSL/Windows ops: skills selection asked once per repo on a real TTY with AINISH_SKILLS_PROMPT_TIMEOUT and saved fallback; SIGTTIN hang fixed by stdin detachment on five call sites (hang→6-8s exit 0); --pqc-install false negative fixed (generated/present/failed); test-pqc-dist.sh 144→150 with a /tmp/uvshim/uv shim, later fixed at 441 after a harness-dependent test drift and canonical author form "Nanoboozhoo embodied by: {agent harness}" (2026-11-05, 2026-11-08, 2026-11-22).
- Diagnostics de-confounded: six "dead" providers were one fixed /v1/chat/completions suffix bug; zero-hit path now carries a reason string in degrade_notes (2026-11-07-memory.txt).
- Deployment trust: native RAG signer preferred, WSL paths converted for Windows .exe, unsigned/legacy-hash manifests refused; signer preflight before any write; snapshot_canonical_contract unlocks/verifies/relocks canonical artifacts and fails closed; gate accepts any envelope matching canonical bytes; post-commit hook skips unmanaged commits; CI parses SHA files (2026-11-04, 2026-11-06, 2026-11-22 records).
- Harness attribution: commit-msg hook strips attribution pre-commit via the 17-harness scripts/harness-attribution.txt (Co-authored-by and Signed-off-by preserved); --rules copies the attribution trio into targets with relative hook blocks, verified self-contained (2026-11-20-memory.txt).
- One Python engine at src/context/engine.py: ainish-coder --context live, ainish-rag a one-line forwarder, Rust crate deleted, missing interpreter a hard error; ML-DSA-65 signing in Python via cryptography/uv with AINISH_MLDSA65_SEED or signer.mldsa65.priv; envelope naming x.md→x.sig; audit verify compares envelope sha256; .agents/context-harness/skills/ the single learned-skill surface; ainish-context context-consolidate with _digest_is_usable (200+ chars, 3 of 4 sections, no promise-opener) (2026-11-19, 2026-11-20-memory.txt).
- aiRPC skill landed and distributed with byte-identical skill indexes; serve/stop/status + /shutdown lifecycle with pid verification; query answered in the ack (2026-11-21-memory.txt).
- License canonicalisation: ainish-coder LICENSE refreshed 1d330ecc…→6b18aab7…, verified byte-identical to nbiish/license-for-all-works main/LICENSE; critical.md §7 fails PRs to main on non-canonical LICENSE; weekly cron integration PR; dist suite 441→445 assertions (2026-11-23-memory.txt).
- Federation: .agents/federation/{YYYY-MM-DD}.md gitignored OS-locked Chain-of-Draft feed with llms.txt contract git-tracked; src/federation_pqc.py Sign-then-Encrypt ainish-coder/federation-envelope/v1 (ML-KEM-768 + ML-DSA-65 + AES-256-GCM + HKDF-SHA3-256) with pinned peer fingerprints and zero plaintext downgrade; _ms_sync_federation fails closed on git check-ignore in both repos (2026-11-25-13-memory.md).
- ainish-coder --context verified end-to-end on local-router's fallback-models route: ~76s full envelope (elephant/goldfish via hermes profiles context-elephant/context-goldfish), ~2.7s --retrieval-only (2026-11-25-memory.txt).
- ainish-rag baseline reworked (nDCG added, embedding identity pinned) (2026-11-06-memory.txt); ~5.6G regenerable caches cleared after internal disk hit 100% (2026-11-21-memory.txt); cross-machine merge 2026-10-30 fast-forwarded ce46980←8389213 preserving 30 remote + six local commits; --plan-check proven in both directions; wiki --index clap flag fixed (DIGEST-memories-2026-10.md, DIGEST-memories-2026-11.md).

## Unfinished

- The Elephant/Goldfish split is an unmeasured hypothesis on this corpus; no measurement ran this period (2026-11-07-memory.txt).
- The four direct-transport chain steps have never run for real on this host: the PQC vault is locked, _pqc_export() returns 0 entries, resolve_driver_key returns None (2026-11-14-00-memory.md).
- ainish-coder --rules <dir> --headless exits 2 after successful deployments (all 13 fleet targets + fresh /tmp probe; --help exits 0); root cause untraced; interim guidance: treat the exit code as unreliable, verify deployed copies in bin/ainish-coder (2026-09-23-memory.txt).
- Local Router interception is a requirement, not a confirmed landing: serveSubcommands must include start and run so the shim intercepts the Unsloth CLI on 8888 (2026-09-23-memory.txt).
- Signer/trust-anchor mismatch: local ML-DSA-65 signer 69e7233d… ≠ committed anchor d98405ea…, so --rules exits 1 after deploying and .agents/canonical lags until the operator's anchor rotation re-signs; deploy-path refreshes append local-signer artifacts to .agents/audit/contract-history.jsonl the rotation must also re-sign (suggestions/2026-11-12-rules-signing-anchor-mismatch.txt; DIGEST-memories-2026-11.md).
- Seven clap bool flags remain in src/rag/src/main.rs (default_value_t = true yields no --no-x); only wiki --index fixed (DIGEST-memories-2026-11.md, 2026-11-12).
- Truncated insight fragment, remainder not recoverable: "Compare models with `driver_model_matches`/`_same_model`, never strings: `zai-g…" — do not infer the missing example or its reasoning (DIGEST-memories-2026-11.md, 2026-11-12).
- Round 14 record ends "(record truncated)"; items after the audit-manifest verification are unknown — check git history if they matter (DIGEST-memories-2026-10.md).
- wsl.exe -l -q output decoding still assumes UTF-16-LE while this Windows build emits UTF-8 (mojibake distro names, never-matching \\wsl.localhost\<distro> probe, Windows silently on a 0-key local store beside 13 WSL keys); byte-shape detection plus trying both wsl.localhost and legacy wsl$ shares is the stated requirement, not a recorded landing (2026-11-06-memory.txt).
- Windows key-store isolation: HOME= does not isolate (Python reads USERPROFILE; pathlib.Path.home() ignores HOME); pinning "the program's own documented override" is stated, not recorded landed (2026-11-06-memory.txt).
- Index-fingerprint provider handling: recording provider disguises failover as corruption and the router route id as a third space; model-vs-provider principle documented, no landed fingerprint change recorded (2026-11-06-memory.txt).
- nDCG range assertion: normalized-against-guessed-ideal produced values above 1.0 (observed 2.131); "a metric needs a range assertion" recorded, addition not recorded (2026-11-06-memory.txt).
- Launcher handoff: bin/ainish-rag exec'd a same-named file beside itself; "compare resolved paths rather than names" recorded as a requirement, not confirmed implemented (2026-11-06-memory.txt).
- bin/ainish-coder must suppress inherited EXIT-tracking traps in command-substitution subshells or --rules can stall during embedding-provider detection; implementation unrecorded (2026-11-04-memory.txt).
- Native compiled RAG binaries required for signing/provider detection; the compiled engine remains a gitignored artifact the operator must supply (2026-11-04, 2026-11-06-memory.txt).
- Production tldraw canvas requires a license key; only development use is free (2026-11-21-memory.txt).
- The omp async daemon broker failed mid-task (disk-full aftermath only suspected); no further diagnosis recorded — backgrounded bash jobs bg_N still delivered results (2026-11-21-memory.txt).
- Stale branch refs left by --branches must be pruned explicitly on both sides of a federation or machines look divergent when main agrees (2026-11-22-memory.txt).
- bunx esbuild shim broken on this host (pnpm global path missing); npx --yes esbuild is the working substitute for TSX parse checks (2026-11-21-memory.txt).
- A repo is one-way under --machine-sync unless listed in links.txt; linking the tool repo must be paired with .agents/no-watcher-autocommit or the watcher leaves wip(<machine>) commits and an unpushed main (2026-11-22-memory.txt).
- Suggestion 2026-11-21-15-attribution-table-test-drift.md named the owner decision for the attribution-table drift; the failing test itself was fixed 2026-11-22, the owner decision stands (2026-11-21, 2026-11-22-memory.txt).
- P0 tasks/plans consolidation deferred to an operator-owned task (2026-11-23-memory.txt).
- PR #18 (fix/context-cli-wiring) implements ainish-coder --context-{seed,status,learn,rollback,promote} launcher wiring and the orientation - gate: line for stale verdicts; the sources do not record it merged (2026-11-25-memory.txt).
- Whether working-LICENSE diverges from canonical main/LICENSE is an open operator promotion decision (2026-11-23-memory.txt).

## Insights

- Exit status is not evidence: verify deployed artifacts, not exit codes (2026-09-23-memory.txt).
- Darwin is not GNU (BSD xargs -r illegal; chmod EPERM once uchg set — an ordering constraint); WSL is the default bash, not Git Bash; MSYS2 rewrites /c, copies exes without DLLs, and normalizes paths inconsistently — environment divergence is the default suspicion (2026-09-23-memory.txt; DIGEST-memories-2026-11.md; 2026-11-25-12-memory.md).
- A check over parsed output can pass vacuously: sed range stopped at the first blank line so the loop never ran; any parse-then-iterate needs a found-something assertion, and a gate must be shown to FAIL before a pass count means anything (DIGEST-memories-2026-11.md, 2026-11-08 and 2026-11-11 entries).
- A gate pinning a literal breaks on the correct edit; 14 pre-existing failures need a baseline before attribution; hand-maintained duplicate lists drift, so derive sets by enumerating the source through the predicate (DIGEST-memories-2026-11.md).
- bin/ainish-rag is the Python engine on this host (launcher forces context/secrets to rag.py; no native binaries exist) — change rag.py, mirror the crate; the vault renderer lives only in src/rag/src/wiki.rs (DIGEST-memories-2026-11.md).
- "Newest wins" means newest by mtime; dropping a filename suffix makes every filter match nothing, which reads as "no plan of record" rather than an error (DIGEST-memories-2026-11.md).
- Deploy-path contract refresh re-signs canonical files and appends to contract-history.jsonl with the local signer; a FAILED ainish-rag wiki still strips frontmatter — revert .agents/{canonical,wiki,audit} after either, chflags nouchg before restoring uchg 444 files; .gitignore lives in .agents/comms/ and must match *.live.{txt,md} (DIGEST-memories-2026-11.md).
- Jev model policy: always LATEST_JEV_MODEL typesafe/jev-1.14, retired ids fail loudly before calibrated local heuristics; JEV_DECISION_MODEL is a surfaced diagnostic pin (DIGEST-memories-2026-10.md).
- A mandatory pack must MIRROR rather than merge, and the no-overwrite flag must be bypassed at the copy layer; diagnostics can agree with the bug they diagnose (shared hardcoded suffix); reporting must describe rather than condemn; the test for a line in an always-read file is "does reading it change what the agent does next" (2026-11-07-memory.txt, 2026-11-14-00-memory.md).
- A saturated metric is a ceiling, not a floor; a vector space is defined by the embedding model, not the provider (openai/text-embedding-3-small bit-identical across zenmux/openrouter/nous-portal, cosine 1.000000, vs text-embedding-3-large cosine 0.0066); a retrieval index cannot detect a foreign vector and a server-side width guard is inert unless the client sends dimensions (2026-11-06-memory.txt).
- SIGTTIN, not slowness, caused the WSL hang: /init reads inherited stdin, the child stops (state T) and takes its timeout watchdog with it; </dev/null completes in 1s; bin/ainish-rag.exe can stay locked by a lingering CLI process — kill the exact PID before copying (2026-11-01, 2026-11-05-memory.txt).
- resolve_canonical_repo_root maps a worktree to the MAIN checkout — right for caches, wrong for tracked learned state; archive_live_generation must run before staging; status: done needs landing corroboration; ainish-rag/<name>/vN strings are on-disk schemas (2026-11-19-memory.txt).
- post-commit cannot strip trailers without an amend, and an amend without -S destroys the signature — commit-msg is the correct hook; the author guard's early exit must require a CLEAN message; hooks live in git rev-parse --git-common-dir/hooks; git filter-repo --message-callback must return bytes, __file__ is undefined, table path via AINISH_HARNESS_TABLE (2026-11-20-memory.txt).
- uchg+444 contract files silently lose edits through editors that don't clear the flag; a 44K-char model prompt hangs the local model intermittently — chunk at 5 records plus one retry; pi_agent_call is an agent, not a function — never gate a destructive step on "reply is non-empty" (2026-11-20-memory.txt).
- .live.txt sidecars are date-prefixed and gitignored, so date-only rules match them and deletion is unrecoverable — test exclusion predicates against constructed cases; one legacy .txt record is invalid UTF-8, so reads use errors="replace"; memories/llms.txt and plans/llms.txt are indexes living inside the folders they index (2026-11-20-memory.txt).
- Fleet staleness keys on deployed content (contract + pack digests), not commit SHA; the canonical signer key is untracked, so re-signing happens on main; a clean federation is one local main plus one peer ref; on Windows delete the old path before renaming a fresh clone into place (2026-11-22-memory.txt).
- tldraw 5.6.2 ShapeUtil requires getGeometry, component and getIndicatorPath(shape): Path2D — the deprecated indicator() is never rendered; wait exit codes: 0 one JSON event, 2 --by deadline expired, 1 hard error; /rpc/wait is at-least-once, re-verify a redelivered call's digest (2026-11-21-memory.txt).
- ~/.cache/{huggingface,modelscope,suno,uv} are symlinks onto an external 1TB volume — deleting there frees nothing internal; the always-on obligation framing (every agent told to run route/orient) functioned as an unmet habit, motivating the rescoping; fresh-install paths hide behind existing state; relaxing a fail-closed trust boundary for a missing artifact is the wrong fix (2026-11-21, 2026-11-05, 2026-11-06-memory.txt).
- .agents/rag/gate-status.json is a cached verdict whose flavour depends on the last invocation (a RED at anchor 100% is a tests verdict); slow --context calls are not hung — HERMES_TIMEOUT_DEFAULT=300s per role; toolless one-shot Hermes requires --profile <name> chat --query-file - --oneshot -Q --source tool --format stream-json --max-turns 1 with platform_toolsets cli: [] (plus memory_enabled/user_profile_enabled false for stateless goldfish) (2026-11-25, 2026-11-25-12 records).
- scripts/test-pqc-dist.sh kills its session shell mid-run — run detached via python3 subprocess with start_new_session=True (setsid is unavailable on macOS); gh GraphQL mutations were flaky — create with a minimal body then PATCH the full body over REST; ML-DSA-65 is untracked, so re-sign on main (2026-11-25, 2026-11-22-memory.txt).
- Superseded memory infrastructure was removed outright rather than kept as legacy paths — relevant if anything still references it (2026-09-23-memory.txt).

## Recurring

- Environment divergence as the default suspicion: Darwin/BSD shell-level failures (xargs -r, chmod/uchg ordering), WSL-is-not-Git-Bash, WSL↔Windows interop silent wrongness (SIGTTIN stops, wsl.exe encoding, .exe path conversion), and MSYS2 invocation traps (2026-09-23-memory.txt; 2026-11-01/04/05/06, 2026-11-25-12 records).
- Hand-maintained duplicates drift: task/plan todo lists, _skills_mandatory_names vs _skill_mandatory, README pack references, harness-attribution naming across stripper/table/test/canonical form, retired packs still linked after deletion (2026-11-07-memory.txt; DIGEST-memories-2026-11.md; 2026-11-20/21/22-memory.txt).
- Fixes aimed at one stall or bypass created new gaps: removing the interactive selector plus defaulting unrecorded packs OFF silently deployed zero packs; deploy_rules_sync wrote manifests before discovering no signer existed on a fresh clone (2026-11-05, 2026-11-06-memory.txt).
- Failures masked by pre-existing state: --pqc-install's bundleExists false negative, Windows 0-key store hidden behind the WSL store's 13 keys, mature-setup baselines needed before attributing the 14 failures (2026-11-05/06/08 records).
- Weak verification gates failed twice (.sig existence passed a rewritten manifest; a non-empty agent reply deleted 16 files) and were replaced by content checks — sha256 comparison, _digest_is_usable (2026-11-19, 2026-11-20-memory.txt).
- The uchg+444 contract files repeatedly blocked legitimate work (silent lost edits, suppressed audit contract failures, worktree-removal leftovers) until snapshot_canonical_contract automated unlock/verify/relock (2026-11-20, 2026-11-22-memory.txt).
- The AGENTS.md ≤160 line gate forced compression twice (contract internals removal, Git & Pull Request Protocol) while the dist suite pins exact phrases such as "Never call a second command to prime yourself" — compression must not paraphrase them; AGENTS.md governance text is repeatedly revised and canonically ML-DSA-65 signed, and LICENSE byte-identity to canonical is a standing gate (2026-11-20, 2026-11-22, 2026-11-23, 2026-11-25-13 records).
