# MEMORY — ainish-coder (curated digest)

One entry per durable fact. Format: `- [YYYY-MM-DD] <fact> *(source: <server/tool>)*` — newest first per section. Contracts live in the `llms.txt` chain, never duplicated here. Exports beside this file are machine snapshots; this file is the curated layer agents iterate on.

## Facts

*(none yet — agents append at session close per `.agents/memories/llms.txt` rule 2)*

## Decisions

- [2026-09-08] All three memory MCP servers (memorix, reference_memory, engram) adopted as the machine-standard memory plane; `.agents/memories/` is their git-tracked record layer. *(source: operator directive, this session)*

## Gotchas

- [2026-09-08] Engram `export`/`import` snapshots include soft-deleted observations — scrub exports for retired memories before committing. *(source: engram v1.20.0 export, this session)*
