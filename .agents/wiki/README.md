---
title: README
aliases: ["wiki", "index", "toc"]
tags: [ainish/wiki/index, ainish/wiki/generated]
generated: 2026-11-28T15:35:00+00:00
source_commit: e0ff062
decision_source: hermes-reviewed
---
# ainish-coder — Knowledge & Architecture Wiki

Generated on: 2026-11-28T15:35:00+00:00 (UTC)
Repository: `ainish-coder`

## Overview
Living architectural map for `ainish-coder` — covering rules deployment (`--rules`, `--llms-txt`), skill-pack distribution (`--skills-sync`, `--select-skills`), graph-first Chain-of-Draft context priming (`--context`, `--context-digest`, `--context-consolidate`), PQC secrets (`pqc-secrets`), and cross-machine federation (`--machine-sync`). Pages are plain markdown with Obsidian frontmatter and `[[wikilinks]]`, compiled by `src/context/engine.py` into `.agents/rag/wiki-graph.json`.

## Contents
- [[01-architecture|01. System Architecture]] — Rules deployment, skills payload split, CoD context engine, and `.agents/` folder taxonomy.
- [[02-codebase-connections|02. Codebase Connections & Symbols]] — CLI entrypoints, shell deploy modules, Python context engine, and PQC/federation wiring.
- [[03-security-and-governance|03. Security & Governance]] — Post-Quantum Cryptography (FIPS 203/204/205), Zero-Trust context hygiene, signed manifests, and security gates.
- [[04-improvements-and-debt|04. Improvements & Technical Debt]] — Active debt, architectural refactors, and the signed operator ledger.
- [[05-research-and-intelligence|05. Research & Intelligence]] — Graph-first retrieval, Chain-of-Draft priming, Elephant-Goldfish Model (EGM), and rolling digest curation.
- [[06-marketing-and-positioning|06. Marketing & Positioning]] — Core value proposition across `--rules`, `--skills`, and `--context` workflows.

## How to read this vault
- **In Obsidian:** open `.agents/wiki/` as a vault; the graph view wires all six domain pages to this index.
- **As an agent:** `ainish-coder --context "<task>"` retrieves sections from these pages as a CoD pointer index + bounded excerpts.
- **Operator notes:** `[[ledger]]` is hand-maintained and never regenerated — append one dated line per cycle.

## Related
- [[01-architecture|System Architecture]]
- [[02-codebase-connections|Codebase Connections]]
- [[03-security-and-governance|Security & Governance]]
- [[04-improvements-and-debt|Improvements & Debt]]
