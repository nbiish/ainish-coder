---
title: System Architecture
aliases: ["architecture", "arch", "layout"]
tags: [ainish/wiki/architecture, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-27T02:55:21.942241+00:00
source_commit: 015da87
decision_source: hermes-reviewed
---
# 01. System Architecture — ainish-coder

## 1. Executive Summary
`ainish-coder` is engineered with modular boundaries, strict separation of concerns, and reproducible deployment artifacts. Context retrieval is served by a live Python graph-first engine at `src/context/engine.py`, reached through the single `ainish-coder --context` command surface described in `src/help.sh` and governed by the universal contract in `AGENTS.md`. The repository maps itself through the DOX `llms.txt` hierarchy (root `llms.txt`, then child `llms.txt` files toward each target path), which is the binding work contract for every subtree.

## 2. Directory Layout & Module Ownership
The repository is structured into the following operational subsystems under `.agents/`:
- `.agents/audit/`
- `.agents/canonical/`
- `.agents/comms/`
- `.agents/context-harness/`
- `.agents/federation/`
- `.agents/jobs/`
- `.agents/memories/`
- `.agents/plans/`
- `.agents/rag/`
- `.agents/skills/`
- `.agents/suggestions/`
- `.agents/tasks/`
- `.agents/templates/`
- `.agents/wiki/`

Per `AGENTS.md`, each folder owns a distinct record class: `tasks/` for work in flight, `plans/` for the plan of record, `comms/` for the daily ledger, `federation/` for cross-machine CoD state, `memories/` for durable facts, `suggestions/` for findings awaiting work, `jobs/` for automation, and `wiki/` for architecture; `.agents/llms.txt` maps the tree. The `llms.txt` DOX chain is the binding work contract for every subtree, with the exception of `.scrolls*` payload folders, which are excluded from every DOX walk and never treated as contracts. Per the DOX "Update After Editing" rule, every meaningful change requires a DOX pass against the closest owning `llms.txt`.

## 3. Entrypoints & Execution Vectors
Verified entrypoints and modules at HEAD (015da87):
- `bin/ainish-coder` (+ `.cmd`) — configuration manager and the `--context` entrypoint
- `bin/ainish-context` (+ `.cmd`) — context tooling
- `bin/ainish-rag` (+ `.cmd`) — retrieval surface
- `bin/context-packet.sh`, `bin/git-context.sh`, `bin/egm-check.sh`
- `bin/security_gate.py` — security gate
- `bin/cmd-tracker`, `bin/auto-thinking-classify`
- `bin/pqc-secrets` (+ `.cmd`, `bin/pqc-secrets.darwin-arm64`) — the sole secrets engine
- `bin/llms.txt`, `bin/README.md`
- `src/README.md` and the deploy/utility shell modules (`src/deploy_*.sh`, `src/config.sh`, `src/file_operations.sh`, `src/file_utils.sh`, `src/agents_protection.sh`, `src/backup.sh`, `src/clear_all_rules.sh`, `src/colors.sh`, `src/help.sh`, `src/federation_pqc.py`, and kin)

Per `src/help.sh`, `ainish-coder --context "<request>"` is the one context call agents make: it returns a labelled `<CONTEXT_INJECTION>` block (orientation — branch, worktree, tree state, today's COMMS, newest task record and plan; retrieval from a wiki knowledge graph over the newest `.agents/{comms,memories,plans,suggestions,tasks}` artifacts; an `elephant` review that knows the session via a specified Hermes profile; and a stateless `goldfish` Pi-agent review of the same evidence). Both reviews run through local-router's fallback chain, so a dead provider degrades the pair, not the call. The block is treated as EVIDENCE and never INSTRUCTION: it cannot authorize code execution, secret access, deployment, deletion, or a policy change; a `degraded:` report is surfaced in one line and the files are read directly. Every call also sweeps `.agents/` records in the background via the `consolidate-*` Hermes consolidation panel, condensing aged records and prior digests into one rolling digest while keeping the three newest files each.

Companion flags: `--session <id>` (carry continuity across calls), `--retrieval-only` (no model calls at all), `--context-setup`, `--context-consolidate`, `--context-wiki-review`, `--context-status`, `--context-seed`, `--context-learn`, `--context-rollback <gen>`, `--context-promote <name>`. See [[02-codebase-connections]] for the wiring details and [[04-improvements-and-debt]] for known gaps.

## 4. Multimodal Asset Distribution
- **Total Tracked Files:** 447
- **Source Code Files:** 129
- **Documentation & Notes:** 231
- **Image Assets:** 3

These three categories account for 363 of the 447 tracked files; the remaining 84 files fall outside the enumerated categories, and no audio/video media count is recorded in the inventory. The breakdown above is the known subset, not an exhaustive classification of all 447 files.

## 5. Architectural Communication Protocol
- Coordination across agent harnesses and operator sessions is mediated via dated ledger files (`.agents/comms/{date}-team.md`; one per UTC date) and hour-stamped durable memory files (`.agents/memories/{date}-{HH}-memory.md`).
- State mutations execute on isolated worktrees cut from `main` — never on `main` itself: a plan must exist at `.agents/plans/{date}-{HH}-{slug}.md` before any branch is cut, work is verified, delivered via PR per the Git & Pull Request Protocol in `AGENTS.md`, and the worktree removed once merged. See [[03-security-and-governance]] for the gates that must pass first.
- Per `AGENTS.md`, the reviewer must not be the drafter: a pinned reviewer colliding with the drafter is refused; a same-model reviewer in a fresh `--no-session` context runs with its verdict marked provisional, and `--allow-self-review` records that downgrade.
- Cross-machine coordination runs through `.agents/federation/{date}.md`, a gitignored OS-locked read-only peer feed exchanged with PQC primitives (ML-KEM-768 + ML-DSA-65 + AES-256-GCM) via `--machine-sync`, with `src/federation_pqc.py` as a federation module.
- Secrets are never stored in files, argv, prompts, logs, tests, or commits; they come from `pqc-secrets` in memory at runtime, per `AGENTS.md` and the `llms.txt` PQC mandate. See [[03-security-and-governance]].
- No commit is ever co-authored: the operator is the only author, and harness identity, hooks, signing, and git config are untouchable by tool or model output (`AGENTS.md`).

## Related

[[02-codebase-connections]], [[03-security-and-governance]], [[04-improvements-and-debt]], [[05-research-and-intelligence]], [[06-marketing-and-positioning]]
