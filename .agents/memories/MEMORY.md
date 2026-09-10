# MEMORY — ainish-coder (curated digest)

One entry per durable fact. Format: `- [YYYY-MM-DD] <fact> *(source: <server/tool>)*` — newest first per section. Contracts live in the `llms.txt` chain, never duplicated here. Exports beside this file are machine snapshots; this file is the curated layer agents iterate on.

## Facts

*(none yet — agents append at session close per `.agents/memories/llms.txt` rule 2)*

## Decisions

- [2026-09-10] Unified repo-memory and graph-intelligence into a single self-prompting skill .agents/skills/repo-memory-graph-intelligence. Establishes the Dual-Recon Loop as a mandatory pre-edit protocol for intaking agents (GitNexus AST 'WHERE' + Repo-Memory 'WHY'). *(source: operator directive, this session)*
- [2026-09-10] Combined /repo-memory (Memorix, Reference Memory, Engram) with /graph-intelligence (GitNexus) via a 4-bridge protocol: AST blast-radius scoped recall, canonical AST UIDs in Reference Memory, diff-to-symbol session summaries, and AST-driven stale memory retirement. Pruned heavy Semantica/Graphify layers in graph-intelligence to focus on pure utilitous AST execution. *(source: operator directive, this session)*
- [2026-09-08] All three memory MCP servers (memorix, reference_memory, engram) adopted as the machine-standard memory plane; `.agents/memories/` is their git-tracked record layer. *(source: operator directive, this session)*

## Gotchas

- [2026-09-10] Unsloth CLI starts its native backend on port 8888 (default) via 'unsloth run -p 8888', while 'unsloth start <agent>' (dsh, hermes) auto-starts the server on 8888 and connects the agent. Local Router shims must intercept on port 8888 and include 'start' and 'run' in serveSubcommands to route unsloth inference to localhost:11434. *(source: local-router unsloth-fix verification, this session)*
- [2026-09-08] Engram `export`/`import` snapshots include soft-deleted observations — scrub exports for retired memories before committing. *(source: engram v1.20.0 export, this session)*
