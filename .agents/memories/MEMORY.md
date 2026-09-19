# MEMORY — ainish-coder (curated digest)

One entry per durable fact. Format: `- [YYYY-MM-DD] [STATE] <statement> *(source: <server/tool>, task: <task-ref>, ast: <symbol>)*` — newest first per section. Contracts live in the `llms.txt` chain, never duplicated here. Exports beside this file are machine snapshots; this file is the curated layer agents iterate on.

## Active Facts

- [2026-09-19] [ACTIVE] Memory CRUD lifecycle establishes active Make, Update, and Delete/Resolve across chat turns and tasks with explicit state tags and AST symbol anchoring. *(source: feat/agent-memory-lifecycle, task: 2026-09-19.memory-lifecycle-task.md, ast: AGENTS.md)*
- [2026-09-19] [ACTIVE] AGENTS.md deploys as plain tracked COPIES (operator directive 2026-09-19): `ainish-coder --rules` copies root → target, never writes through links; guard hook is warn-only and self-replaces the legacy blocking block; `scripts/hooks/agents-md-sync.sh` re-syncs global copies post-merge/post-checkout. *(source: feat/agents-md-copy-deploy, task: 2026-09-19.agents-md-copy-task.md, ast: deploy_agents)*
- [2026-09-19] [RESOLVED 2026-09-19] AGENTS.md symlink protection (chflags uchg/chmod 444/chattr +i/attrib +R + blocking pre-commit guard) — superseded by copy deployment after the blocking guard trapped downstream agents (local-router T-typechange deadlock); symlink facts below retained for the retired `--lock-rules` opt-in path only. *(source: feat/rules-cross-platform-posix, superseded-by: feat/agents-md-copy-deploy, ast: lock_agents_contract)*
- [2026-09-19] [ACTIVE] Pre-commit hook guard uses POSIX printf for color escapes and prepends itself right after the hook shebang (#!/bin/sh) so it executes before downstream logic or early exit 0 statements. *(source: feat/rules-cross-platform-posix verification, task: 2026-09-19.posix-cross-platform-task.md, ast: scripts/setup-hooks.sh)*

## Active Decisions

- [2026-09-19] [ACTIVE] Fast memory orientation integrated into bin/git-context.sh so agents receive instant situational memory summaries alongside comms, tasks, and suggestions. *(source: feat/agent-memory-lifecycle, task: 2026-09-19.memory-lifecycle-task.md, ast: bin/git-context.sh)*
- [2026-09-19] [ACTIVE] Multi-tier SHA-256 calculation fallback order: sha256sum -> shasum -a 256 -> openssl dgst -sha256 -> python3 -> python -> powershell.exe -> cksum guarantees zero external dependency breakage across Linux, macOS, BSD, and Windows. *(source: feat/rules-cross-platform-posix, task: 2026-09-19.posix-cross-platform-task.md, ast: _calc_sha256)*
- [2026-09-10] [ACTIVE] Unified repo-memory and graph-intelligence into a single self-prompting skill .agents/skills/repo-memory-graph-intelligence. Establishes the Dual-Recon Loop as a mandatory pre-edit protocol for intaking agents (GitNexus AST 'WHERE' + Repo-Memory 'WHY'). *(source: operator directive, ast: .agents/skills/repo-memory-graph-intelligence/SKILL.md)*
- [2026-09-10] [ACTIVE] Combined /repo-memory (Memorix, Reference Memory, Engram) with /graph-intelligence (GitNexus) via a 4-bridge protocol: AST blast-radius scoped recall, canonical AST UIDs in Reference Memory, diff-to-symbol session summaries, and AST-driven stale memory retirement. Pruned heavy Semantica/Graphify layers in graph-intelligence to focus on pure utilitous AST execution. *(source: operator directive, ast: .agents/skills/repo-memory-graph-intelligence/SKILL.md)*
- [2026-09-08] [ACTIVE] All three memory MCP servers (memorix, reference_memory, engram) adopted as the machine-standard memory plane; `.agents/memories/` is their git-tracked record layer. *(source: operator directive)*

## Active Gotchas

- [2026-09-19] [ACTIVE] On macOS (BSD xargs), the -r (--no-run-if-empty) flag is illegal and causes git hooks to fail. Use portable while IFS= read loops instead of xargs -r. *(source: scripts/setup-hooks.sh fix, task: 2026-09-19.posix-cross-platform-task.md)*
- [2026-09-19] [ACTIVE] On macOS (Darwin), chmod fails with EPERM if the uchg user immutable flag is already active. In lock_agents_contract, call chmod 444 before chflags uchg; in unlock_agents_contract, call chflags nouchg before chmod 644. *(source: src/agents_protection.sh, task: 2026-09-19.posix-cross-platform-task.md, ast: lock_agents_contract)*
- [2026-09-10] [ACTIVE] Unsloth CLI starts its native backend on port 8888 (default) via 'unsloth run -p 8888', while 'unsloth start <agent>' (dsh, hermes) auto-starts the server on 8888 and connects the agent. Local Router shims must intercept on port 8888 and include 'start' and 'run' in serveSubcommands to route unsloth inference to localhost:11434. *(source: local-router unsloth-fix verification, ast: bin/local-router.js)*
- [2026-09-08] [ACTIVE] Engram `export`/`import` snapshots include soft-deleted observations — scrub exports for retired memories before committing. *(source: engram v1.20.0 export)*

## Resolved / Retired Archive

*(No retired entries yet. When bugs are permanently resolved or dead code is pruned, move items here with `[RESOLVED YYYY-MM-DD]` and a resolution note.)*
