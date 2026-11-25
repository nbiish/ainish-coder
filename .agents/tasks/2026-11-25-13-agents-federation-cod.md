# Task: Cross-Machine Chain of Draft (CoD) Federation Ledger & AGENTS.md Integration Reminder

- lane: now
- branch: `feat/agents-federation-cod`
- worktree: `/Users/nbiish/code/ainish-coder-worktrees/feat-agents-federation-cod`
- status: done
- plan: `.agents/plans/2026-11-25-13-agents-federation-cod.md`
- scope: `AGENTS.md`, `.agents/canonical/AGENTS.{md,md.sha256,sig}`, `.agents/federation/llms.txt`, `.agents/llms.txt`, `llms.txt`, `.gitignore`, `src/federation_pqc.py`, `src/templates/AGENTS.FEDERATION.md`, `src/deploy_agents_federation.sh`, `src/machine_sync.sh`, `bin/ainish-coder`, `src/deploy_rules_sync.sh`, `src/deploy_agents.sh`, `src/help.sh`, `src/README.md`, `src/context/engine.py`, `src/context/master-surfaces.json`, `src/context/tests/*`, `scripts/test-machine-sync.sh`, `scripts/test-pqc-dist.sh`
- compat: additive and backward-compatible — adds gitignored, OS-locked agent-read-only `.agents/federation/{date}.md` exchanged inside FIPS 203 ML-KEM-768 + FIPS 204 ML-DSA-65 + AES-256-GCM envelopes by `--machine-sync` (fail-closed on `git check-ignore`, fingerprint mismatch, or missing PQC primitives; no plaintext downgrade) and concise parallel-PR/branch integration guidance in `AGENTS.md` (158/160 lines, canonically ML-DSA-65 signed).
- objective: Add PQC agent-read-only `.agents/federation/{date}.md` Chain of Draft (CoD) cross-machine communication (gitignored, peer-transferred via `--machine-sync`) and update `AGENTS.md` so every agent inspects open PRs, branches, and federation CoD state before deciding whether to integrate into the user's request or create a new integration PR.

## Verification & Closeout Evidence (2026-11-25)

- `bash -n bin/ainish-coder src/deploy_agents_federation.sh src/machine_sync.sh src/deploy_rules_sync.sh src/deploy_agents.sh src/help.sh`: pass (exit 0)
- `python3 -m py_compile src/federation_pqc.py src/context/engine.py`: pass (exit 0)
- `bash bin/ainish-coder --plan-check .`: pass (`Plan of record: ./.agents/plans/2026-11-25-13-agents-federation-cod.md`)
- `wc -l AGENTS.md`: **158** (within ≤160-line gate); `ainish-context audit contract --threshold 1` + `--verify-history`: **PASS** (ML-DSA-65 signed, 66 hash-chained transitions verified)
- `python3 -m unittest src/context/tests/test_federation_pqc.py -v`: **3/3 pass** (ML-KEM-768 + ML-DSA-65 + AES-256-GCM roundtrip, tampered ciphertext & peer fingerprint change fail-closed refusal, secret/PII/bidi/sensitive-path scrubbing, read-only lock)
- `python3 -m unittest src/context/tests/test_context_injection.py -k OrientationSectionTest -v`: **17/17 pass** (including federation CoD & sibling-branch orientation surfacing)
- `python3 -m unittest src/context/tests/test_gate_ready.py src/context/tests/test_wiki_graph.py -v`: `test_shared_state_is_append_only` pass (3 pre-existing baseline failures unchanged from `main`: `test_shared_rules_file_is_loaded_and_strip_ansi`, `test_generation_refuses_to_clobber_a_vault`, `test_wikilinks_survive_a_refused_run`)
- `bash scripts/test-machine-sync.sh`: **67 passed, 0 failed** (including §19 PQC read-only gitignored federation CoD exchange, union-merge, clean git trees, and unenrolled-repo `git check-ignore` protection)
- `PQC_CONFIG_DIR=<tmp> PQC_STORE_ISOLATED=1 bash scripts/test-pqc-dist.sh </dev/null`: **PASS: 457 assertion(s), 0 failed**
- Context call note: `ainish-coder --context` prompted interactively for a vault passphrase on this host and was cancelled without blocking per `AGENTS.md`; all repo state was verified directly from files and git.
- Rebuild verdict: `no-rebuild-needed` (repo ships no long-running server).
