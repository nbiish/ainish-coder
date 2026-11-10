---
title: "04. Improvements & Technical Debt"
aliases:
  - "04 Improvements and Debt"
  - "Improvements and Technical Debt"
tags:
  - agents/wiki
  - debt
  - ledger
generated: true
---

# 04. Improvements & Technical Debt — ainish-coder-context-prime

## See also

- [[01 Architecture|System Architecture]]
- [[02 Codebase Connections|Codebase Connections and Symbols]]
- [[03 Security and Governance|Security and Governance]]
- [[05 Research and Intelligence|Research and Intelligence]]
- [[06 Marketing and Positioning|Marketing and Positioning]]
- [[ledger|Operator Ledger]]

## 1. Actionable Refactor Targets
1. **Multimodal Indexing Expansion:** Continuously refresh LanceDB vectors upon meaningful git commits.
2. **Deterministic Build Pipeline:** Ensure all binary targets compile with zero warnings across macOS, Linux, and Windows MSVC.
3. **Zero-Stale Memory Scrubbing:** Retire resolved constraints in `.agents/memories/` using `[RESOLVED]` entries.

## 2. Operator ledger
`ainish-rag wiki` rewrites pages 01–06 and README.md. It never writes `.agents/wiki/ledger.md`. Append one dated line there per cycle. This section is that file, spliced in on each generation.

### [[ledger|Operator Ledger]]

# Operator ledger

`ainish-rag wiki` regenerates `01`–`06` and `README.md`. It does not touch this file. Append one dated line per cycle. The generator splices this file into `04-improvements-and-debt.md`.

- [RESOLVED] 2026-10-28 Wiki pages were overwritten on every `wiki` run, so iterative notes never survived. The generator now splices this ledger into page 04.
- [RESOLVED] 2026-10-28 Psionics vault RAG records probe misses in `psionics-self-hypnosis/.agents/wiki/ledger.md` (`uv run -m tools.rag.verify`). Read that file before the next index or context-map pass.
- [RESOLVED] 2026-10-28 Verified Round 8 operator ledger signing, path redaction, and memory cross-linking.
- [RESOLVED] 2026-10-29 (d693f37) Round 9 verified HEAD SHA, ANSI scrubbing, and intoto binding.
- [RESOLVED] 2026-10-29 (7843e11) Round 10 stdin pipeline test with MAC [REDACTED:MAC]
