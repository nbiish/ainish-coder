---
title: Codebase Connections & Symbols
aliases: ["connections", "symbols", "calls"]
tags: [ainish/wiki/connections, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-27T02:27:48.970916+00:00
source_commit: 015da87
decision_source: hermes-reviewed
---
# 02. Codebase Connections & Symbols — ainish-coder

## 1. Component Linkage & Call Graph
Codebase components in `ainish-coder` communicate across well-defined interfaces and CLI surfaces.

- **CLI entrypoints (`bin/`):** `ainish-coder` (the singular command surface — rules deployment, context priming, PQC install/status, skills sync), `ainish-context` (context-engine shim), `ainish-rag` (retrieval CLI), `pqc-secrets` (secret engine wrapper, with a `pqc-secrets.darwin-arm64` fast-path binary), `security_gate.py`, `auto-thinking-classify`, `cmd-tracker`, plus shell helpers (`context-packet.sh`, `git-context.sh`, `egm-check.sh`) and Windows `.cmd` counterparts.
- **Shell module layer (`src/`):** `config.sh`, `help.sh`, `colors.sh`, `file_operations.sh`, `file_utils.sh`, `backup.sh`, `agents_protection.sh` underpin the deploy family — `deploy_agents.sh`, `deploy_agents_comms.sh`, `deploy_agents_federation.sh`, `deploy_commands.sh`, `deploy_rules_sync.sh`, `deploy_skills.sh`, `deploy_mcp.sh`, `deploy_mcp_recipes.sh`, `deploy_scrolls.sh`, `deploy_signals.sh`, `deploy_llms_txt.sh`, `deploy_gitignore.sh`, `deploy_license.sh`, `deploy_github_actions.sh`, `deploy_local_security.sh`, `deploy_critical.sh`, `deploy_template_agent.sh`, `deploy_unlock.sh`, `clear_all_rules.sh`, `src/deploy_agents.sh`.
- **Context engine (live):** the knowledge-retrieval engine is `src/context/engine.py`, a graph-first Python engine over the wiki vault and `.agents/` context folders — markdown sections as nodes, wikilinks and bounded shared vocabulary as edges. It backs `ainish-coder --context` and its sibling subcommands (`--context-setup`, `--context-consolidate`, `--context-wiki-review`, `--context-status`, `--context-seed`, `--context-learn`, `--context-rollback`, `--context-promote`), including the `--retrieval-only` no-model path and `--session` continuity.
- **Federation & identity:** `src/federation_pqc.py` and the `bin/pqc-secrets` wrapper implement the cross-machine CoD ledger exchange (`.agents/federation/{date}.md`, read-only agent feed) and the identity/signing surfaces; see [[03-security-and-governance|Security & Governance]].
- **Universal contract:** `AGENTS.md` binds every agent in a target repo to the one-context-call workflow, worktree isolation off `main`, verified delivery, and operator-only commit authorship; `llms.txt` (DOX hierarchy) binds each subtree to its nearest contract. Architecture context lives in [[01-architecture|System Architecture]].

## 2. External Dependencies & Subsystems
- Zero external heavy dependencies; platform standard library oriented.
- Crypto surfaces use the `pqc-secrets` engine (cross-platform Python canonical, optional darwin/arm64 binary) with OS keystore opt-ins (macOS Keychain, Linux Secret Service); see [[03-security-and-governance|Security & Governance]].
- Review pair (`elephant` session-aware reviewer + `goldfish` stateless reviewer) and the background `consolidate-*` panel run through local-router's fallback chain; a dead provider degrades the pair, not the call.

## 3. Cross-Cutting Concerns
- **PQC Secrets Decoupling:** Cryptographic operations are isolated from application logic through FIPS 203/204/205 tools — ML-KEM-768 + ML-DSA-65 + AES-256-GCM, vault-first identity, prompt-free bootstrap, one-bundle-one-machine.
- **Knowledge Retrieval:** graph-first over the wiki vault and `.agents/` context folders — markdown sections as nodes, wikilinks and bounded shared vocabulary as edges — powered by the live Python engine at `src/context/engine.py` behind `ainish-coder --context`.
- **Rules Synchronization:** Rules and agent contracts propagate outward from `ainish-coder` to target repositories via `--rules` deployment (AGENTS.md copy, gitignore, comms board, federation ledger) and `--llms-txt` DOX installs.
- **Consolidation Loop:** every context call sweeps aged `.agents/{comms,memories,plans,suggestions,tasks}` records in the background via the `consolidate-*` Hermes panel, keeping the three newest files and rolling the rest into dated digests; `--context-consolidate` runs it on demand. See [[README|Vault index]].

## Cross-Repository Surfaces
- **Agent Communication System:** merge-safe daily boards at `.agents/comms/{date}-team.md` (gitignored `.live.md` live board never touched).
- **Subsystems under `.agents/`:** `audit/`, `canonical/`, `comms/`, `context-harness/`, `federation/`, `jobs/`, `memories/`, `plans/`, `rag/`, `skills/`, `suggestions/`, `tasks/`, `templates/`, `wiki/` — each mapped by `.agents/llms.txt` and read by the context engine as retrieval sources.
- **Self-improvement loop:** `--context-status` reports what is live/staged/rejected, `--context-learn` runs an opt-in propose→gate cycle, `--context-rollback <gen>` restores a past harness generation, and `--context-promote` moves staged skills operator-side.

## Related

[[01-architecture]], [[03-security-and-governance]], [[04-improvements-and-debt]], [[05-research-and-intelligence]], [[06-marketing-and-positioning]]
