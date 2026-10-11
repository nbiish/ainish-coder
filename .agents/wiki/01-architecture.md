# 01. System Architecture — ainish-rag

## 1. Executive Summary
`ainish-rag` is engineered with modular boundaries, strict separation of concerns, and reproducible deployment artifacts.

## 2. Directory Layout & Module Ownership
The repository is structured into the following operational subsystems:
- `.agents/`
- `.agents/canonical/`
- `.agents/comms/`
- `.agents/memories/`
- `.agents/rag/`
- `.agents/rag/lancedb/`
- `.agents/skills/`
- `.agents/skills/8thfire-scrolls/`
- `.agents/skills/8thfire-scrolls/benchmarks/`
- `.agents/skills/8thfire-scrolls/benchmarks/b6/`
- `.agents/skills/8thfire-scrolls/benchmarks/embodiment/`
- `.agents/skills/8thfire-scrolls/embodiment/`
- `.agents/skills/8thfire-scrolls/governance/`
- `.agents/skills/8thfire-scrolls/research/`
- `.agents/skills/advisory-council/`
- `.agents/skills/anishinaabe-cyberpunk-style/`
- `.agents/skills/browser-skill/`
- `.agents/skills/browser-skill/references/`
- `.agents/skills/browser-use/`
- `.agents/skills/code-security/`


## 3. Entrypoints & Execution Vectors
The primary execution boundaries and user-facing entrypoints:
- `bin/git-context.sh`
- `bin/lib/auto_thinking_context.sh`
- `bin/lib/mcp_discover.py`
- `bin/lib/mcp_settings.sh`
- `bin/lib/providers.sh`
- `bin/lib/tracker.sh`
- `bin/security_gate.py`
- `src/cmd-tracker/src/main.rs`
- `src/pqc-secrets/src/main.rs`
- `src/rag/src/main.rs`


## 4. Multimodal Asset Distribution
- **Total Tracked Files:** 255
- **Source Code Files:** 93
- **Documentation & Notes:** 129
- **Image Assets:** 3
- **Audio / Video Media:** 0

## 5. Architectural Communication Protocol
- Coordination across agent harnesses and operator sessions is mediated via dated ledger files (`.agents/comms/{date}-team.txt`) and durable memory files (`.agents/memories/{date}-memory.txt`).
- State mutations execute on task worktrees (`feat/*`, `fix/*`, `chore/*`) and merge autonomously when verification gates pass.
