---
title: Improvements & Technical Debt
aliases: ["improvements", "debt", "todo", "refactors"]
tags: [ainish/wiki/improvements, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-27T02:57:00+00:00
source_commit: 015da87
decision_source: hermes-reviewed
---

# 04. Improvements & Technical Debt — ainish-coder

## 1. Active Debt & Code Hotspots
Grounded items tracked across the live codebase and consolidated digests:
- **Test baseline drift:** `test_shared_rules_file_is_loaded_and_strip_ansi` in `src/context/tests/test_gate_ready.py` remains a pre-existing failure independent of the context consolidation pipeline.
- **Local-router chain health & stale builds:** `.agents/suggestions/2026-11-26-14-local-router-stale-build-trap.md` and `2026-11-25-18-local-router-chain-drift-and-health-401s.md` track upstream provider quarantine/401 drift and launchd stale-build restarts outside this repo.
- **Pair transport durability:** `.agents/suggestions/2026-11-25-18-pair-transport-durability.md` tracks `pi` intermittent empty blocks and Hermes latency budgets on high-latency hosts.
- **Shell temp-file hygiene:** `bin/egm-check.sh`, `scripts/commit-identity-guard.sh`, `src/deploy_rules_sync.sh`, `src/pqc_dist.sh`, `src/machine_sync.sh`, `src/verify_skills.sh`, and `src/file_operations.sh` manage temporary files via `mktemp` and should preserve trap-based cleanup.

## 2. Recommended Architectural Refactors
1. **Living Wiki Freshness & Compilation:** Keep `.agents/wiki/` reviewed via `ainish-coder --context-wiki-review` and compiled into `.agents/rag/wiki-graph.json` alongside every consolidation sweep.
2. **Bounded Coordination Folders:** Maintain steady state across `.agents/{comms,memories,plans,suggestions,tasks}` at the 3 newest chronological originals plus 1 canonical `consolidates.{naming}.md` file via the 4-profile Hermes consolidation panel (`consolidate-elephant`, `consolidate-goldfish`, `consolidate-archivist`, `consolidate-structural`).
3. **Cross-Platform Verification:** Keep `src/context/tests/` Python tests, shell syntax checks, and FIPS 203/204 PQC signing gates green across macOS, Linux, and Windows.

## Related
- [[03-security-and-governance|Security & Governance]]
- [[05-research-and-intelligence|Research & Intelligence]]
- [[README|Vault index]]

## 3. Operator ledger
Spliced verbatim from `.agents/wiki/ledger.md` (read-only historical operator log; never rewritten by `ainish-coder --context-wiki-review`).

# Operator ledger

`ainish-rag wiki` regenerates `01`–`06` and `README.md`. It does not touch this file. Append one dated line per cycle. The generator splices this file into `04-improvements-and-debt.md`.

- [RESOLVED] 2026-10-28 Wiki pages were overwritten on every `wiki` run, so iterative notes never survived. The generator now splices this ledger into page 04.
- [RESOLVED] 2026-10-28 Psionics vault RAG records probe misses in `psionics-self-hypnosis/.agents/wiki/ledger.md` (`uv run -m tools.rag.verify`). Read that file before the next index or context-map pass.
- [RESOLVED] 2026-10-28 Verified Round 8 operator ledger signing, path redaction, and memory cross-linking.
- [RESOLVED] 2026-10-29 (d693f37) Round 9 verified HEAD SHA, ANSI scrubbing, and intoto binding.
- [RESOLVED] 2026-10-29 (7843e11) Round 10 stdin pipeline test with MAC [REDACTED:MAC]
