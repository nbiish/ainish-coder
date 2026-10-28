# 04. Improvements & Technical Debt — ainish-coder

## 1. In-Flight Debt & Code Hotspots
The following actionable items and markers were identified across the codebase:
- **`src/rag/src/wiki.rs:137`**: if line.contains("TODO") || line.contains("FIXME") || line.contains("XXX") {
- **`src/rag/src/wiki.rs:308`**: todo_list.push_str("- No explicit TODO/FIXME markers discovered in codebase.\n");
- **`src/verify_skills.sh:464`**: ing_root="$(mktemp -d "$skills_source/.ainish-ingest.XXXXXX")"


## 2. Recommended Architectural Refactors
1. **Multimodal Indexing Expansion:** Continuously refresh LanceDB vectors upon meaningful git commits.
2. **Deterministic Build Pipeline:** Ensure all binary targets compile with zero warnings across macOS, Linux, and Windows MSVC.
3. **Zero-Stale Memory Scrubbing:** Retire resolved constraints in `.agents/memories/` using `[RESOLVED]` entries.

## 3. Operator ledger
`ainish-rag wiki` rewrites pages 01–06 and README.md. It never writes `.agents/wiki/ledger.md`. Append one dated line there per cycle. This section is that file, spliced in on each generation.

# Operator ledger

`ainish-rag wiki` regenerates `01`–`06` and `README.md`. It does not touch this file. Append one dated line per cycle. The generator splices this file into `04-improvements-and-debt.md`.

- 2026-10-28 Wiki pages were overwritten on every `wiki` run, so iterative notes never survived. The generator now splices this ledger into page 04.
- 2026-10-28 Psionics vault RAG records probe misses in `psionics-self-hypnosis/.agents/wiki/ledger.md` (`uv run -m tools.rag.verify`). Read that file before the next index or context-map pass.
