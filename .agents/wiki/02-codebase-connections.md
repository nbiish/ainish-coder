---
title: "02. Codebase Connections & Symbols"
aliases:
  - "02 Codebase Connections"
  - "Codebase Connections and Symbols"
tags:
  - agents/wiki
  - architecture
generated: true
---

# 02. Codebase Connections & Symbols — ainish-coder-context-prime

## See also

- [[01 Architecture|System Architecture]]
- [[03 Security and Governance|Security and Governance]]
- [[04 Improvements and Debt|Improvements and Technical Debt]]
- [[05 Research and Intelligence|Research and Intelligence]]
- [[06 Marketing and Positioning|Marketing and Positioning]]
- [[ledger|Operator Ledger]]

## 1. Component Linkage & Call Graph
Codebase components in `ainish-coder-context-prime` communicate across well-defined interfaces and CLI surfaces.

## 2. Cross-Cutting Concerns
- **PQC Secrets Decoupling:** Cryptographic operations are isolated from application logic through FIPS 203/204/205 tools.
- **RAG & Knowledge Retrieval:** Codebase symbols and documentation chunks are vectorized using EmbeddingGemma-2 (768-d) and queried via LanceDB hybrid search.
- **Rules Synchronization:** Rules and agent contracts propagate outward from `ainish-coder` to target repositories via `--rules` deployment.
