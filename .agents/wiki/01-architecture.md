---
title: System Architecture
aliases: ["architecture", "arch", "layout"]
tags: [ainish/wiki/architecture, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-28T15:35:00+00:00
source_commit: e0ff062
decision_source: hermes-reviewed
---
# 01. System Architecture — ainish-coder

## 1. Executive Summary
`ainish-coder` is a cross-platform rules, skills, and context manager for AI coding agents. Its three core subsystems are:
1. **Rules & DOX Deployment (`--rules`, `--rules-sync`, `--llms-txt`):** distributes the singular universal contract (`AGENTS.md`), `.gitignore`, daily COMMS boards, PQC federation ledgers, and DOX `llms.txt` contracts with ML-DSA-65 signed manifests and fleet auto-sync.
2. **Skills Distribution (`--skills-sync`, `--select-skills`, `--skills-list`, `--skills-verify`):** distributes mandatory (`ainish-security`, `pqc-secrets`) and operator-selected optional skill packs from `skills-to-distribute/skills/` into target `.agents/skills/` directories with newest-mtime bidirectional sync.
3. **Graph-First Context & Digest Engine (`--context`, `--context-digest`, `--context-consolidate`):** `src/context/engine.py` compiles `.agents/wiki/` and `.agents/` coordination folders into `.agents/rag/wiki-graph.json` and emits concise Chain-of-Draft `<CONTEXT_INJECTION>` primes backed by an Elephant/Goldfish review pair.

## 2. `.agents/` Folder Taxonomy & Ownership
Each folder under `.agents/` owns one record class (mapped by `.agents/llms.txt`):
- `comms/` — daily UTC session ledgers (`{date}-team.md`; gitignored `*.live.*` sidecars untouched).
- `tasks/` — hour-stamped active/completed task records (`{date}-{HH}-{slug}.md`).
- `plans/` — hour-stamped design plans with 8-key frontmatter and §5 todos (`{date}-{HH}-{slug}.md`).
- `memories/` — hour-stamped scrubbed durable facts (`{date}-{HH}-memory.md`).
- `suggestions/` — outliving findings awaiting future work (`{date}-{HH}-{slug}.md`).
- `federation/` — gitignored, OS-locked read-only cross-machine CoD peer feed (`{date}.md`), PQC-synced by `--machine-sync`.
- `jobs/` — declarative automation records (`consolidate-record.md`, `learn-harness.md`, `sync-fleet.md`).
- `wiki/` — this Obsidian architectural vault (`README.md`, `01`–`06`, and signed `ledger.md`/`ledger.sig`).
- `skills/` — curated standing skill packs for this repository (distinct from the full distributable payload in `skills-to-distribute/skills/`).
- `context-harness/` — per-repo retrieval tuning (`prime-profile.json`) and staged learned skills.
- `audit/` & `canonical/` — generated ML-DSA-65 receipts and canonical contract copies (never hand-edited).
- `rag/` — local ignored caches (`wiki-graph.json`, `gate-status.json`, `sessions/`, `digest-prune-log.jsonl`).

## 3. Core Entrypoints & Context Flow
- `bin/ainish-coder` (+ `.cmd`) — primary CLI dispatcher for `--rules*`, `--skills*`, `--context*`, `--pqc-*`, and `--machine-*`.
- `bin/ainish-context` (+ `.cmd`) — direct launcher for `src/context/engine.py` (with `bin/ainish-rag` kept only as a deprecation shim).
- `bin/pqc-secrets` (+ `.cmd`, `pqc-secrets.darwin-arm64`) — FIPS 203/204/205 secrets engine wrapper.
- `bin/security_gate.py`, `bin/context-packet.sh`, `bin/git-context.sh`, `bin/egm-check.sh` — pre-merge gates and context helpers.

`ainish-coder --context "<request>"` emits one budgeted, Chain-of-Draft `<CONTEXT_INJECTION>` envelope:
1. `orientation` — code-only state (`rules`, `gate`, `branch`, `worktree`, `working tree`, `COMMS`, `federation CoD`, `newest task`, `newest plan`, deduplicated peer branches).
2. `retrieval` — CoD pointer index (`path:Lstart-Lend (score) -> gist`) + bounded excerpts from the compiled wiki graph (demoting `AGENTS.md` unless the query asks about rules/contract).
3. `elephant` — session-aware CoD bullets from Hermes profile `context-elephant`.
4. `goldfish` — stateless 3-step `pi --no-session --no-tools` review (comprehension, antagonistic, readiness verdict) bounded by `token_cap`.

Companion commands: `--retrieval-only`, `--session <id>`, `--context-digest` (`--review`/`--check`/`--uncheck`/`--prune`), `--context-consolidate`, `--context-wiki-review`, `--context-setup`, `--context-status`, `--context-seed`, `--context-learn`, `--context-rollback <gen>`, `--context-promote <name>`.

## 4. Coordination & Delivery Protocol
- Work starts with a plan in `.agents/plans/{date}-{HH}-{slug}.md`, executes in an isolated worktree off `origin/main` (never on `main`), verifies via tests and gates, and delivers via PR with operator-only authorship (`AGENTS.md`).
- Reviewer independence is enforced structurally (`--no-session` for Goldfish; colliding explicit pins are refused; same-model fresh-context reviews are marked `PROVISIONAL`).
- Secrets resolve strictly from `pqc-secrets` in memory at runtime (never in files, prompts, logs, or commits); non-interactive `--context` detaches from `/dev/tty` so locked vaults fail fast instead of hanging.

## Related
[[02-codebase-connections]], [[03-security-and-governance]], [[04-improvements-and-debt]], [[05-research-and-intelligence]], [[06-marketing-and-positioning]]
