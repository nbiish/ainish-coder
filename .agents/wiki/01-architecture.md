---
title: System Architecture
aliases: ["architecture", "arch", "layout"]
tags: [ainish/wiki/architecture, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-11T18:50:47.579860+00:00
source_commit: 275bbff
decision_source: structural
---

# 01. System Architecture — repo

## 1. Executive Summary
`repo` is engineered with modular boundaries, strict separation of concerns, and reproducible deployment artifacts.

## 2. Directory Layout & Module Ownership
The repository is structured into the following operational subsystems:
- `.agents/`
- `.agents/audit/`
- `.agents/canonical/`
- `.agents/comms/`
- `.agents/memories/`
- `.agents/plans/`
- `.agents/rag/`
- `.agents/skills/`
- `.agents/skills/8thfire-scrolls/`
- `.agents/skills/8thfire-scrolls/benchmarks/`
- `.agents/skills/8thfire-scrolls/benchmarks/b6/`
- `.agents/skills/8thfire-scrolls/benchmarks/embodiment/`
- `.agents/skills/8thfire-scrolls/embodiment/`
- `.agents/skills/8thfire-scrolls/governance/`
- `.agents/skills/8thfire-scrolls/research/`
- `.agents/skills/advisory-council/`
- `.agents/skills/ainish-security/`
- `.agents/skills/ainish-security/references/`
- `.agents/skills/anishinaabe-cyberpunk-style/`
- `.agents/skills/browser-skill/`


## 3. Entrypoints & Execution Vectors
The primary execution boundaries and user-facing entrypoints:
- `bin/context-packet.sh`
- `bin/git-context.sh`
- `bin/egm-check.sh`
- `bin/lib/mcp_discover.py`
- `bin/lib/providers.sh`
- `bin/lib/tracker.sh`
- `bin/lib/mcp_settings.sh`
- `bin/lib/auto_thinking_context.sh`
- `bin/security_gate.py`
- `src/pqc-secrets/src/main.rs`
- `src/rag/src/main.rs`
- `src/cmd-tracker/src/main.rs`


## 4. Multimodal Asset Distribution
- **Total Tracked Files:** 347
- **Source Code Files:** 119
- **Documentation & Notes:** 172
- **Image Assets:** 3
- **Audio / Video Media:** 0

## 5. Architectural Communication Protocol
- Coordination across agent harnesses and operator sessions is mediated via dated ledger files (`.agents/comms/{date}-team.txt`) and durable memory files (`.agents/memories/{date}-memory.txt`).
- State mutations execute on task worktrees (`feat/*`, `fix/*`, `chore/*`) and merge autonomously when verification gates pass. See [[03-security-and-governance]] for the gates that must pass first.


## Related
- [[02-codebase-connections|Codebase Connections]]
- [[03-security-and-governance|Security & Governance]]
- [[README|Vault index]]

