---
title: Research & Intelligence
aliases: ["research", "intelligence", "sources"]
tags: [ainish/wiki/research, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-28T15:35:00+00:00
source_commit: e0ff062
decision_source: hermes-reviewed
---
# 05. Research & Intelligence — ainish-coder

## 1. Graph-First Retrieval Architecture
- **Engine:** `src/context/engine.py` compiles `.agents/wiki/*.md`, `AGENTS.md`, `llms.txt`, `.agents/{comms,federation,memories,plans,suggestions,tasks}`, `.agents/templates/`, `research/`, and staged learned skills into `.agents/rag/wiki-graph.json`.
- **Graph mechanics:** markdown sections are nodes; `[[wikilinks]]`, markdown links, and bounded shared vocabulary are edges; rare task terms seed a 1-hop expansion with recency tie-breaking and `KIND_INTENT` boosts when a query names a corpus layer.
- **No external vector stack:** retrieval requires no embedding model, no vector store, and no background server; the cache invalidates automatically on source mtime or corpus-definition changes.

## 2. Chain-of-Draft (CoD) Context Priming & EGM Pair
- **CoD envelope:** `ainish-coder --context` emits compact, arrow-chained output across `orientation`, `retrieval` (pointer index first + bounded excerpts, demoting `AGENTS.md` unless the query asks about rules/contract), `elephant`, and `goldfish`.
- **Elephant-Goldfish Model (EGM):** `context-elephant` (Hermes profile) synthesizes session-aware continuity; `goldfish` (`pi --print --no-session --no-tools`) runs stateless 3-step review (comprehension, antagonistic, readiness verdict) strictly bounded by `token_cap` so reviewer prose never starves `retrieval`.
- **Per-repo harness tuning:** `.agents/context-harness/prime-profile.json` holds generation-tracked retrieval tuning (`--context-seed`, `--context-status`, `--context-learn`, `--context-rollback`, `--context-promote`).

## 3. Rolling Consolidation & Digest Curation
- **Consolidation panel:** background sweeps (`--context-consolidate`) run four Hermes profiles (`consolidate-elephant`, `consolidate-goldfish`, `consolidate-archivist`, `consolidate-structural`) to roll aged records into one `consolidates.{naming}.md` per folder while protecting the 3 newest chronological originals.
- **Fail-closed digest pruning:** `ainish-coder --context-digest` (`--review`, `--check`, `--uncheck`, `--prune`) provides stable `<folder>:<n>` IDs so operators can audit and prune obsolete digest bullets without risking unreviewed data loss; future consolidation sweeps omit `- [x]` items during compaction.

## 4. Federation & Decision Layer
- **TypeSafe Jev & Local Calibrated Router:** `DecisionEngine` routes queries (`needs_retrieval`, domain, freshness, budget) via OpenRouter / loopback Local Router Decisions API with deterministic local calibrated fallback.
- **PQC Federation CoD:** `.agents/federation/{date}.md` exchanges ultra-terse `<≤7w> -> <≤7w> -> <≤7w>` peer branch/PR state across machines inside ML-KEM-768 + ML-DSA-65 + AES-256-GCM envelopes.

## Related
[[01-architecture]], [[02-codebase-connections]], [[03-security-and-governance]], [[04-improvements-and-debt]], [[06-marketing-and-positioning]]
