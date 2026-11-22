---
format: ainish/context-digest/v1
folder: memories
period: 2026-10
records_consolidated: 8
consolidated_at: 2026-11-20T22:11:07.580611+00:00
sources:
  - 2026-10-11-memory.txt
  - 2026-10-12-memory.txt
  - 2026-10-24-memory.txt
  - 2026-10-26-memory.txt
  - 2026-10-28-memory.txt
  - 2026-10-29-memory.txt
  - 2026-10-30-memory.txt
  - 2026-10-31-memory.txt
---

# Digest — `.agents/memories`, 2026-10

This digest replaces 8 record(s) from 2026-10. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Accomplished

Built and hardened `ainish-rag`, a multimodal/codebase RAG system (Rust core in `src/rag/` + Python in `src/rag/rag.py`) on EmbeddingGemma-2 + LanceDB, deployed via `ainish-coder --rules`. Each round shipped a native `bin/ainish-rag.exe` and passed `bin/security_gate.py` and `ainish-rag gate` (cited to their dates):

- **2026-10-11** — Foundation: 6-part living wiki in `.agents/wiki/`, 281 chunks in LanceDB; verified query returned `03-security-and-governance.md` at 0.6940 cosine. Jev decision-model two-stage reranking (noul/score, 70% utility + 30% vector), later RRF K=60 (40% RRF + 30% vector + 20% terms + 10% symbols). Cross-platform support (Windows/WSL/Linux/macOS) for HF cache, PQC vault, detached llama-server. Supply-chain + anti-DNS: llama binary SHA256 check, host memory caps, loopback Host/Origin validation, FIPS 204 ML-DSA-65 signed index receipts, drift monitor.
- **2026-10-12** — Rounds 3 & 4: loopback PSK auth (`--api-key`, Bearer/X-Ainish-PSK), configurable symbol salt, immutable model manifest, systemd/Windows service generator, healthcheck retry (3x, exp backoff), `audit verify`, Orient high-divergence advisory, `--tui` status. Also PSK TTL rotation, PII/credential redaction pre-embed, lockfile integrity, NUMA/affinity, LanceDB compaction/WAL prune, CycloneDX 1.6 + SPDX 3.0.1 SBOM, `eval --patch`, `orient --inject`, `query --fzf`. Canonical AGENTS.md got a 5-step `<TASK_PRIMER>` + `<REFERENCE>`; multi-agent canonical-root resolver anchoring sibling worktrees to shared `.agents/rag`.
- **2026-10-24** — Round 6: real-time anti-DNS/IP-binding (`validate_loopback_host`), Gaussian differential-privacy noise (`--dp-epsilon`, L2 re-normalization), in-toto v1.0 provenance, shared mmap reader pool, synthetic drift injection + self-healing recovery, k-of-n threshold ML-DSA-65 contract signing, AST-guided diff import-repair patch generator, task-conditioned wiki ranking, gate bell/toast. 9/9 Rust tests.
- **2026-10-26** — Round 7: constant-time PSK verify + rate limiting, cumulative DP budget ledger (`.agents/audit/privacy-budget.json`), `Cargo.lock` checksum verification (727 crates), adaptive batch sizing (4–64 by RTT), chaos fault-injection, FIDO2/TPM2.0 hardware-seal, `gate --watch`. 12/12 tests. Normalized 20 CRLF files to LF + added `.gitattributes`; guarded `grep` under `pipefail` so `--rules` runs clean on WSL/Linux/macOS.
- **2026-10-28** — Removed merged worktree `D:/Code/agents-rag-playbook` after `<SERVERS>` 4-point check; spliced `.agents/wiki/ledger.md` into `04-improvements-and-debt.md` in both Rust (`read_operator_ledger`) and Python (`generate_wiki`); merged + pushed `feat/wiki-operator-ledger` and `feat/rag-round8-masters` to `origin/main`. Round 8: credential/PII scrubbing + local-path redaction on ledger, `wiki_ledger_sha256` attestation, `cleanup --prune-worktrees`, ML-DSA-65 `ledger.sig`, ledger in `orient --inject`, `[RESOLVED]` memory cross-linking, `wiki --note`. 13/13 Rust tests, 6/6 ML-DSA-65 receipts verified.
- **Round 9** (`d693f37`) — verified HEAD SHA, ANSI scrubbing, in-toto binding; `agent:<name>`/`agent:antigravity` removed from `src/templates/AGENTS.COMMS.md`, `src/scroll_integrity.sh`, `.agents/skills/orchestrate-subagent-masters/SKILL.md`, `.agents/comms/*.txt`, `.agents/suggestions/*.txt` so COMMS and suggestion headers are fully harness-agnostic. All 9 masters suggestions implemented across `src/rag/src/{wiki,main,pqc}.rs`, `src/rag/rag.py`; AGENTS.md resynced at sha256 `ee748d8a…`; 13/13 tests, 7/7 audit receipts; gate GREEN.
- **Round 10** (`7843e11`, `feat/rag-round10-complete-wrapup`) — Trojan Source bidi-override rejection (`contains_bidi_override`), MAC redaction (`[REDACTED:MAC]`), `.gitattributes` SHA-256 lockfile pinning, `cleanup --delete-merged --dry-run`, `wiki --list-notes --json`, open/resolved counts in `ainish-rag status` and `bin/git-context.sh`, `wiki --note -` via stdin, `gate --summary`. Canonical sha `9d32a576…`; 14/14 tests; pushed to `origin/main`.
- **Round 11** (`feat/rag-round11-operational-automation`) — Zero-Trust `zt:OK` row, `audit privacy [--max-budget <eps>] [--reset] [--json]` with `--dp-max-budget` enforcement, automatic in-toto + CycloneDX SBOM refresh on `audit lock --update`, `service status --warm`, `store.verify_or_recover()` in `bench --regression --chaos` with `.agents/rag/bench-baseline.json` snapshot, hash-chained `contract-history.jsonl` with auto-signing in `src/agents_protection.sh`, symbol anchors in `orient --inject`, `ainish_rag_statusline` helpers, TTY-safe `query --fzf`. Canonical sha `b81cca83…`.
- **Round 12** (`feat/rag-round12-full-verification`) — full Zero-Trust/Loopback-PSK/Trojan-Source verification in `gate`, `verify_redaction_pipeline` self-test wired into `audit privacy` and `gate`, `Cargo.lock` pinned with zero external deps, `.agents/rag/runtime-profile.json` persistence, 8/8 audit receipts verified, `orient --inject --verify`, `sync_bidirectional_resolutions`, `statusline` subcommand. Canonical sha `adf8a9bb…`; 15/15 tests.
- **Round 13** (`feat/rag-round13-masters`) — `gate --strict` requiring STRONG_ANCHOR >= 70%, `audit privacy --out .agents/audit/privacy-report.json` plus `.sig`, detached SBOM `.sig` verification inside `audit lock`, `compact` inject mode, `wiki --sync-resolved`, `statusline --json`. Canonical sha `b488ba94…`; 16/16 Rust tests.
- **Round 14 (partial record)** — `AINISH_GATE_STRICT=1` auto-strict gate mode, `ainish:privacy-report:sha256` recorded in CycloneDX 1.6 SBOM properties, `.agents/audit/model-manifest.sig` verification in `audit manifest` (record truncated).
- **Cross-machine merge 2026-10-30** — `origin/main` `ce46980` fast-forwarded as `8389213`, preserving 30 remote and six local commits.
- **Embedding provider plumbing** (`src/rag/src/provider.rs`) — resolution order: operator intent (env `AINISH_EMBED_PROVIDER` or persisted `.agents/rag/embed-provider.json`), then env, then the PQC store via `pqc-secrets export --json` held in memory only. `provider::write_config` persists only `provider`, `provider_id`, `api_base`, `model`, `dim`, `key_source`, `source`; the key never reaches disk or logs. OpenRouter and ZenMux `/embeddings` verified live at HTTP 200, 1536 dims. Remote batch sizing auto-scales 32 → 128 by RTT (below 1500 ms doubles, above 6000 ms halves); 3,355 chunks embedded in 28 requests rather than 840.
- **Decision layer on OpenRouter Decisions API** (`https://openrouter.ai/api/alpha/decisions`, models `typesafe/jev-1.14-20261014` / `jev-1.13`). `DecisionEngine::resolve_api_key` goes through `provider::resolve_named_secret`, so PQC-stored `LOCALROUTER_OPENROUTER_API_KEY` is visible. Rerank is one bundled request for up to 12 candidates × 4 questions, blending 0.45/0.25/0.30 with 0.08/0.03 discounts then 70% decision + 30% vector; end-to-end query ≈ 2.8 s. `RerankResult.role` serialises as `decision_role`; local RRF fallback emits `role="unknown"`.
- **Policy** — always target `LATEST_JEV_MODEL = typesafe/jev-1.14`, no silent downgrade to 1.13; `JEV_DECISION_MODEL` is a diagnostic pin surfaced by `ainish-rag secrets` as `model_pinned`; a retired id fails loudly before falling back to calibrated local heuristics.
- **`decision::discover_local_router`** probes `$JEV_LOCAL_ROUTER_URL` (default `http://127.0.0.1:11434`, then `localhost`) against `/v1/models` plus three decisions paths; a usable route becomes a `local-router:<url>:<model>` fallback transport that never receives the OpenRouter key. Chat-only routers are reported rather than substituted (`Decisions Route: none (chat-only entry; typed decisions stay on OpenRouter)`). Every `source`/`evaluation_source`/`rationale` names its transport.
- **Local Router 1.1.0** verified as a real typed decisions transport (`61467cf`): `/api/alpha/decisions`, `/v1/decisions`, `/decisions` answer the canonical body; pinned `openrouter/jev-1.14` and `zenmux/jev-1.14` survive curation; failover is availability-only and reports attempts. A query with an invalid primary key produced `local-router:http://127.0.0.1:11434/api/alpha/decisions:typesafe/jev-1.14-20261014` rationales (direct 0.84, symbols 0.95, utility 3.51, role implementation) in 3.5 s.
- **Skill pack** `.agents/skills/typesafe-jev/` (SKILL.md, 4 references, `scripts/jev_probe.py`) passes `bin/security_gate.py` front-matter validation and appears in the harness catalog; `jev_probe.py` resolves keys the same way as the engine and never prints them; verified live at noul 0.970, choice confidence 1.00.
- **Rules registry migration is code, not a data fix** — `_ainish_rules_migrate_legacy_registry` seeds `targets.txt` from `rules-targets.json` plus the `repos` map in `skills-selection.json` on first read, dropping dead paths and anything under `/tmp`, `/var/tmp`, `/private/var/folders`.
- **Ephemeral model lifecycle** — `LlamaServer::mark_ephemeral` + `EphemeralServerGuard` (Drop) kill only servers the current process spawned, on every exit path; `serve` and `service status --warm` set keep=true; `--keep-server` / `AINISH_RAG_KEEP_SERVER=1` opts out; `stop --purge` also removes `session.psk*`. A stale 2,034 MB operator llama was reclaimed by `ensure_running` when switching to API and did not return.
- **Test state at close** — Rust 44/44 and Python 41/41 passing after the decision-layer work (16/16 at Round 13). Final main state 2026-10-30 was `8a83fdb` plus `ec198b3`, gate GREEN at 82.4% STRONG_ANCHOR, `bin/ainish-rag.exe` rebuilt at 21:58, no resident llama/ainish-rag process.
- **Recurring delivery each round** — canonical AGENTS.md synced to a recorded SHA-256, Rust suite green, `ainish-rag gate` + `bin/security_gate.py` GREEN.

## Unfinished

- `2026-10-29-memory.txt` cuts off mid-entry at Round 14 (`tests::`), so the remaining Round 14 items, test counts, and merge status are not recoverable.
- `2026-10-31-memory.txt` cuts off mid-word inside the `ainish_temp_be…` gotcha (macOS `mktemp`/`mv` EXDEV workaround); the intended fix for cross-device `--rules` runs is not recorded.
- The legacy `sync-rules-targets.sh` post-merge hook was still doing the real AGENTS.md refreshes as of the migration; whether it was retired after `targets.txt` began being seeded is unrecorded.
- The eight live repos previously held only in `~/.config/ainish-coder/rules-targets.json` are not enumerated in these records.
- Four branches (`feat/rag-round4-masters`, `feat/rag-round6-masters`, `feat/rag-round7-masters`, round-3 `feat/advanced-masters-sota`) are not stated as merged, unlike `feat/wiki-operator-ledger` and `feat/rag-round8-masters`; whether rounds 3/4/6/7 landed on main is unconfirmed.
- No entry is recorded as started-but-stopped, but each round's features are self-attested at the memory level, not independently re-verified here.

## Insights

- EmbeddingGemma-2 **requires BF16/FP32; FP16 produces NaN embeddings** (2026-10-11); the `gemma-embedding2` arch error was resolved by bumping llama.exe to b11540 (AVX-512 BF16).
- llama.cpp FlashAttention strictly needs `-fa on` / `--flash-attn on` in b11540+; bare `-fa` fails (2026-10-11).
- LanceDB 0.15 pins Arrow 53 and needs `protoc.exe` for prost-build (2026-10-11).
- HF model cache lives on external drive `D:\AI\huggingface\hub` (unsloth embeddinggemma-2-GGUF with separate `mmproj-F16.gguf`) (2026-10-11).
- The `pipefail` + unguarded `grep -n '^<PROTOCOL>$'` interaction in `src/deploy_agents_comms.sh` broke `ainish-coder --rules` on WSL/Linux/macOS; CRLF line endings were the other portability trap (2026-10-26).
- Canonical AGENTS.md is SHA-256-pinned and signed each round (`.agents/canonical/AGENTS.sig`, FIPS 204 ML-DSA-65); audit receipts, SBOM, and in-toto provenance all carry detached ML-DSA-65 signatures.
- Every worktree carries tracked `.agents/` (skills, canonical), so `resolve_canonical_repo_root(worktree)` returns the worktree itself. LanceDB, PID file, PSK, and provider config are therefore per-worktree, and gate/eval against the wrong index reports UNGROUNDED; fleet-level gate checks must run from the main checkout.
- Signing in a worktree without `.agents/audit/signer.mldsa65.priv` mints a fresh random seed, so `audit verify` reports "signed by a key other than the trust anchor". Sign on main (priv file present, gitignored) or copy the seed into the worktree.
- `.agents/canonical/AGENTS.md` carries the macOS `uchg` flag; a fast-forward aborts with "Operation not permitted" until `chflags nouchg`.
- The canonical-contract sequence after editing `AGENTS.md` is mandatory: `ainish-rag audit contract` on main, then commit `.agents/canonical/{AGENTS.md,*.sha256,*.sig,*.threshold.sig}`; until then the gate's Zero-Trust `canonical_sha256_match` stays red.
- `ainish-rag index --rebuild` is required after any embedding-provider switch; `.agents/rag/index-fingerprint.json` stores `identity` (e.g. `api:openrouter:openai/text-embedding-3-small`) plus `dim`, and a mismatch prints a rebuild warning from `ensure_running`. Output model is `openai/text-embedding-3-small` at 1536 dims, truncated and renormalised to the store's 768 via `provider::DEFAULT_STORE_DIM`.
- `pqc-secrets` on Windows is a `.cmd` shim `CreateProcess` cannot launch; `provider::export_secrets` routes it through `cmd /C` and honours `PQC_SECRETS_BIN`.
- `uv run` selects Python 3.10 here, where backslashes inside f-string expressions are illegal; extract them into variables in `src/rag/rag.py`.
- An apostrophe inside a `${var:-default}` word opens a single-quoted region for bash and surfaces only as "unexpected EOF" at end of file. Keep parameter-expansion defaults quote-free and re-run `bash -n` after every edit.
- `SCRIPT_DIR` is re-pointed at `src/` by sibling modules, so `${SCRIPT_DIR}/ainish-coder` never resolves; address the launcher via `_ainish_rules_cli` (`REPO_DIR/bin/ainish-coder`). The old `--rules-sync` fallback path was dead.
- The Decisions API is strict: `criteria` is mandatory per type — `{true,false}` for noul, an object keyed by option for choice, an array one-per-level for score. The previous engine parsed `decisions`/`value`/`probability`, a shape the endpoint no longer returns, and silently emitted defaults even on HTTP 200.
- `typesafe/jev-router` appears in `/api/v1/models` but is a chat router, not a decision model; the Decisions API rejects it ("does not exist"). Likewise `openrouter-jev-router` advertised by local-router at `127.0.0.1:11434` 404s on all three decisions paths, and a chat completion for it resolved to `anthropic/claude-opus-5.5` — a chat alias.
- `--embed-config --detect` delegates to `ainish-rag embed-provider` inside the target repo, and `--rules` persists config only when a real remote credential exists; auto-detection that finds nothing writes nothing.

## Recurring

- **Rounds follow one cadence**: implement N "masters suggestions" (9/9, 9, 9, 12, 13, 14, 15, 16) across the Rust **and** Python engines in lockstep, recompile `bin/ainish-rag.exe`, resync + re-hash canonical AGENTS.md, run `ainish-rag gate` + `bin/security_gate.py`, report GREEN. Appears in every 2026-10 memory file.
- **Canonical AGENTS.md re-sync + re-signing after every round**, Rounds 9–13 and again on 2026-10-30 and 2026-10-31, always paired with a fresh Rust/Python test count and a GREEN gate — the default close-out for any change.
- **Parity discipline**: essentially every capability exists twice, Rust + Python, under the same names (`validate_loopback_host`, `scrub_sensitive_content`, `verify_psk_constant_time`, `reader_pool`/`_table_pool`).
- **Security is layered and accretes**: loopback/anti-DNS + PSK auth, differential privacy, PII/scrubbing, FIPS 204 ML-DSA-65 signing recur and pile up across rounds rather than being one-shot.
- **Per-worktree state confusion** (index, PID, PSK, provider config, canonical root) recorded on 2026-10-30 and 2026-10-31 as a distinct gotcha.
- **Worktree signing with a missing `signer.mldsa65.priv`** appears twice (2026-10-30 01:42, 2026-10-31 01:26), each framed as "reconfirmed from the previous session" — same failure, same remedy.
- **Silent-fallback failure mode** recurs: decision engine emitting defaults on a 200 with an unparsed shape, rules registry reporting "none registered" while the legacy hook did the real work, the auto-intent bug fixed in `8a83fdb` — all "looks healthy, isn't". It is why fail-closed and loud-retirement policies (retired Jev id fails loudly, chat-only routers reported not substituted) were adopted.
- **Shell quoting is the top cause of total-failure incidents**: one apostrophe in a `${var:-default}` broke every `ainish-coder` invocation while sourcing `embed_config.sh`, fixed in `ec198b3` and verified with `bash -n`, `--embed-config --status`, `--embed-config --detect --json`.
- **Cross-platform portability is re-touched repeatedly**: cache/vault path hierarchies, detached server spawning, line-ending normalization, the `pipefail` guard.
- **macOS filesystem behaviour breaks tooling in three ways**: `uchg` on canonical AGENTS.md, `mv` EXDEV on cross-device renames from `mktemp` in `$TMPDIR`, and the Windows `.cmd` shim for `pqc-secrets`. Platform handling must be code, not convention.
- **Worktree hygiene**: worktrees removed after merge with an ownership check (2026-10-28), matching the AGENTS.md contract.

---
Note: the trailing `{"event":"local_router.failover",...}` payload (2026-11-20T22:10:43Z, `local-router/fallback-models` → `kilo-baidu-ernie-5.5-flash-preview-free-paid`) is not a memory record and contains no instruction acted on here; treated as data per the agent contract.

## Review

The digest is not faithful — it is mostly unsupported by the five sources, which end at Round 8 (2026-10-28).

Unsupported assertions (present in digest, absent from every source):
- **Rounds 9, 10, 11, 12, 13, 14** with commit SHAs (`d693f37`, `7843e11`, etc.), and all their feature lists (Trojan-Source bidi rejection, MAC redaction, `gate --strict` STRONG_ANCHOR ≥ 70%, `contract-history.jsonl`, `runtime-profile.json`, `statusline`, etc.). None of this is in the sources.
- **Dates after 2026-10-28**: "Cross-machine merge 2026-10-30", `ce46980`/`8389213`, "30 remote and six local commits".
- **Embedding provider plumbing** (`src/rag/src/provider.rs`, `embed-provider.json`, OpenRouter/ZenMux `/embeddings` at 1536 dims, "3,355 chunks in 28 requests", batch 32→128). Not in sources.
- **Decision layer specifics**: model ids `typesafe/jev-1.14-20261014`/`jev-1.13`, `LATEST_JEV_MODEL`, blend weights 0.45/0.25/0.30 with 0.08/0.03 discounts, `RerankResult.role`/`decision_role`, "≈2.8 s". The 10-11 source only mentions Jev OpenRouter decisions generically and the 70/30 + RRF K=60 (40/30/20/10) split — not these figures.
- **`discover_local_router`, "Local Router 1.1.0" (`61467cf`), `kilo-baidu-ernie` failover** — not in sources.

The trailing JSON `local_router.failover` event is not a source file; treat as injected data, not digest material.

Genuine source facts the digest omits (from 2026-10-12, 21:38–23:25 block): quarantine `.scrolls*`/classical-crypto token redaction in `orient --inject`; `RE_CANARY` canary/credential scanning in `eval --patch` with repair import hints; worktree-aware CPU/batch auto-scaling in `server.rs` via `git worktree list`; `bench --save-baseline`/`--regression` against `bench-baseline.json`; `orient --inject --json` and the unified `ainish-rag gate` card ("Autonomous Merge Authorized"); and the specific canonical hashes for that day.

Minor omissions from 2026-10-11: the 23:45 details that `-fa` requires an explicit `on` argument in llama.cpp b11540+, and the 8192 batch/ubatch alignment.

The five source files' own content (Rounds 1–8) is otherwise represented accurately.
