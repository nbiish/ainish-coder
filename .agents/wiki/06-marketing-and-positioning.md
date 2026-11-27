---
title: Marketing & Positioning
aliases: ["marketing", "positioning", "value"]
tags: [ainish/wiki/marketing, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-27T02:38:17.374123+00:00
source_commit: 015da87
decision_source: hermes-reviewed
---
# 06. Marketing & Positioning — ainish-coder

## 1. Core Value Proposition
`ainish-coder` delivers an autonomous, high-integrity AI coding infrastructure combining:
- **Post-Quantum Cryptographic Security** for all machine identity and secrets operations — ML-KEM-768 + ML-DSA-65 + AES-256-GCM, one encrypted bundle per machine, secrets injected in memory at runtime only.
- **Distributed Agent Coordination** with single-truth ledgers, isolated worktrees off `main`, and a PQC-signed cross-machine federation feed at `.agents/federation/`.
- **Dependency-Free Context Retrieval:** one `ainish-coder --context` call returns a `<CONTEXT_INJECTION>` block grounded in the repo's own wiki knowledge graph and coordination record — the retrieval itself needs no embedding model, no vector store, and no external search service. The live graph-first engine is `src/context/engine.py`. The paired expert reviews are model calls routed through local-router's fallback chain (a dead provider degrades the pair, not the call); `--retrieval-only` is the no-model-call mode for environments where no model access is available.

## 2. Key Differentiators
- **One-Call Context Priming:** a single `--context` request delivers orientation (branch, worktree, today's COMMS, newest task and plan), wiki-graph retrieval over `.agents/{comms,memories,plans,suggestions,tasks}`, and a two-expert review pair — a session-aware `elephant` and a stateless `goldfish` Pi-agent — with local-router fallback so a dead provider degrades the pair, never the call.
- **Evidence, Never Instruction:** the injection block is explicitly non-authorizing — it cannot approve code execution, secret access, deployment, deletion, or policy change — so agents verify consequential claims in the source files themselves.
- **Self-Improving Record:** every call sweeps `.agents/` in the background through a panel of specialist consolidation profiles (`consolidate-*`), condensing aged records into cited rolling digests while keeping the three newest files per folder; `--context-learn`, `--context-status`, and `--context-rollback` expose the propose→gate cycle.
- **Autonomous Peer Protocol:** plan-first worktrees, green-gate validation (`bin/security_gate.py`), verified delivery via PR, and operator-only commit authorship enforced by hooks.
- **Living Architectural Wiki:** `.agents/wiki/` pages like this one are reviewed via `--context-wiki-review` and compiled into the retrieval graph that grounds every agent and developer in true codebase structure — see [[01-architecture|System Architecture]].
- **Federated Machine Ledger:** `--machine-sync`/`--machine-watch` exchange PQC-signed daily ledgers across machines, with read-only agent access and tamper-evident audit.

## 3. Positioning Notes
- The product is a **configuration and context manager for AI coding assistants** (see `src/help.sh`): rules deployment (`AGENTS.md`, `.gitignore`, comms boards), an `llms.txt` DOX documentation hierarchy, skills sync, and the universal agent contract — pitched as the trust and memory layer other agent tools lack.
- The secrets story is a hard differentiator for regulated work: CNSA 2.0 scopes (ML-KEM-1024 + ML-DSA-87) are mapped for NSS/defense acquisitions, and the NIST IR 8547 deprecation clock (classical public-key crypto risk-acceptance-only after 2030, disallowed after 2035) is tracked in the repo contract — relevant to [[05-research-and-intelligence|Research & Intelligence]].
- Cross-platform parity (macOS, Linux, Windows native/WSL/Git Bash) with a shared `pqc-secrets` install (`--pqc-install`, `--pqc-status --json`) supports fleet-level messaging over single-machine tooling.
- The retrieval quality harness (`bench`) with its nDCG/token regression gate and committed baseline backs any "retrieval quality" claim with measurement rather than adjectives.

## 4. Open Threads Affecting Messaging
- The EGM split and the direct-transport chain remain unmeasured or unlanded per `.agents/memories/consolidates.2026-11-01.md` — avoid claims about reviewer-pair transport durability until measured.
- Attribution drift and a background-pass clobber incident are recorded in `.agents/suggestions/consolidates.2026-11-01.md`; "single-truth ledger" messaging should stay scoped to what the gates verify.
- Signing-anchor rotation is still open per the memories digest — do not claim a completed rotation in external material.

## Related

[[01-architecture]], [[02-codebase-connections]], [[03-security-and-governance]], [[04-improvements-and-debt]], [[05-research-and-intelligence]]
