---
title: Improvements & Technical Debt
aliases: ["improvements", "debt", "todo", "refactors"]
tags: [ainish/wiki/improvements, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-11T18:50:47.612135+00:00
source_commit: 275bbff
decision_source: structural
---

# 04. Improvements & Technical Debt — repo

## 1. In-Flight Debt & Code Hotspots
The following actionable items and markers were identified across the codebase:
- **`bin/egm-check.sh:53`**: if grep -nE '(^|[^[:alnum:]])TODO([^[:alnum:]]|$)|<short name>|<path>' "$design" >/dev/null 2>&1; then
- **`bin/egm-check.sh:54`**: echo 'FAIL: unresolved placeholder or TODO'
- **`scripts/test-machine-sync.sh:25`**: WORK="$(mktemp -d "${TMPDIR:-/tmp}/machine-sync-test.XXXXXX")"
- **`scripts/test-pqc-dist.sh:33`**: WORK="$(mktemp -d "${TMPDIR:-/tmp}/pqc-dist-test.XXXXXX")"
- **`src/deploy_rules_sync.sh:376`**: tmp="$(mktemp "${TMPDIR:-/tmp}/ainish-pack.XXXXXX" 2>/dev/null)" || return 1
- **`src/pqc_dist.sh:41`**: tmp="$(mktemp "${TMPDIR:-/tmp}/pqc-pack.XXXXXX" 2>/dev/null)" || return 1
- **`src/machine_sync.sh:189`**: idx="$(mktemp "${TMPDIR:-/tmp}/ainish-ms-idx.XXXXXX" 2>/dev/null)" || return 1
- **`src/machine_sync.sh:675`**: bundle="$(mktemp "${TMPDIR:-/tmp}/ainish-ms-bundle.XXXXXX" 2>/dev/null)" || { _ms_err "mktemp failed"; return 1; }
- **`src/verify_skills.sh:529`**: ing_root="$(mktemp -d "$skills_source/.ainish-ingest.XXXXXX")"
- **`src/file_operations.sh:11`**: if tmp="$(mktemp "${dest}.XXXXXX" 2>/dev/null)"; then
- **`src/rag/rag.py:3361`**: ("technical_debt", "known gaps, TODOs, refactors, drift, or maintenance risk"),
- **`src/rag/src/decision.rs:1034`**: ("technical_debt", "known gaps, TODOs, refactors, drift, or maintenance risk"),
- **`src/rag/src/wiki.rs:223`**: if line.contains("TODO") || line.contains("FIXME") || line.contains("XXX") {
- **`src/rag/src/wiki.rs:473`**: todo_list.push_str("- No explicit TODO/FIXME markers discovered in codebase.\n");


## 2. Recommended Architectural Refactors
1. **Multimodal Indexing Expansion:** Continuously refresh LanceDB vectors upon meaningful git commits.
2. **Deterministic Build Pipeline:** Ensure all binary targets compile with zero warnings across macOS, Linux, and Windows MSVC.
3. **Zero-Stale Memory Scrubbing:** Retire resolved constraints in `.agents/memories/` using `[RESOLVED]` entries.

## 3. Operator ledger
`ainish-rag wiki` rewrites pages 01–06 and README.md. It never writes `.agents/wiki/ledger.md`. Append one dated line there per cycle. This section is that file, spliced in on each generation.


## Related
- [[03-security-and-governance|Security & Governance]]
- [[05-research-and-intelligence|Research & Intelligence]]
- [[README|Vault index]]


# Operator ledger

`ainish-rag wiki` regenerates `01`–`06` and `README.md`. It does not touch this file. Append one dated line per cycle. The generator splices this file into `04-improvements-and-debt.md`.

- [RESOLVED] 2026-10-28 Wiki pages were overwritten on every `wiki` run, so iterative notes never survived. The generator now splices this ledger into page 04.
- [RESOLVED] 2026-10-28 Psionics vault RAG records probe misses in `psionics-self-hypnosis/.agents/wiki/ledger.md` (`uv run -m tools.rag.verify`). Read that file before the next index or context-map pass.
- [RESOLVED] 2026-10-28 Verified Round 8 operator ledger signing, path redaction, and memory cross-linking.
- [RESOLVED] 2026-10-29 (d693f37) Round 9 verified HEAD SHA, ANSI scrubbing, and intoto binding.
- [RESOLVED] 2026-10-29 (7843e11) Round 10 stdin pipeline test with MAC [REDACTED:MAC]
