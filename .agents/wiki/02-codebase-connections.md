---
title: Codebase Connections & Symbols
aliases: ["connections", "call-graph", "symbols"]
tags: [ainish/wiki/connections, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-13T01:02:49.043627+00:00
source_commit: 2225493
decision_source: structural
---

# 02. Codebase Connections & Symbols — ainish-coder

## 1. Component Linkage & Call Graph
Codebase components in `ainish-coder` communicate across well-defined interfaces and CLI surfaces.

## 2. External Dependencies & Subsystems
- Zero external heavy dependencies; platform standard library oriented.


## 3. Cross-Cutting Concerns
- **PQC Secrets Decoupling:** Cryptographic operations are isolated from application logic through FIPS 203/204/205 tools.
- **Knowledge Retrieval:** graph-first over the wiki vault and `.agents/` context folders — markdown sections as nodes, wikilinks and bounded shared vocabulary as edges. The EmbeddingGemma-2 / LanceDB vector path was DELETED 2026-11-12.
- **Rules Synchronization:** Rules and agent contracts propagate outward from `ainish-coder` to target repositories via `--rules` deployment.


## Related
- [[01-architecture|System Architecture]]
- [[03-security-and-governance|Security & Governance]]
- [[README|Vault index]]

