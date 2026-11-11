---
title: Codebase Connections & Symbols
aliases: ["connections", "call-graph", "symbols"]
tags: [ainish/wiki/connections, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-11T18:50:47.591171+00:00
source_commit: 275bbff
decision_source: structural
---

# 02. Codebase Connections & Symbols — repo

## 1. Component Linkage & Call Graph
Codebase components in `repo` communicate across well-defined interfaces and CLI surfaces.

## 2. External Dependencies & Subsystems
- Zero external heavy dependencies; platform standard library oriented.


## 3. Cross-Cutting Concerns
- **PQC Secrets Decoupling:** Cryptographic operations are isolated from application logic through FIPS 203/204/205 tools.
- **RAG & Knowledge Retrieval:** Codebase symbols and documentation chunks are vectorized using EmbeddingGemma-2 (768-d) and queried via LanceDB hybrid search.
- **Rules Synchronization:** Rules and agent contracts propagate outward from `ainish-coder` to target repositories via `--rules` deployment.


## Related
- [[01-architecture|System Architecture]]
- [[03-security-and-governance|Security & Governance]]
- [[README|Vault index]]

