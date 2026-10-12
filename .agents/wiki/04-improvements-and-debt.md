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
