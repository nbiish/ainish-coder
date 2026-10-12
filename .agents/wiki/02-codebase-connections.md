# 02. Codebase Connections & Symbols — ainish-coder

## 1. Component Linkage & Call Graph
Codebase components in `ainish-coder` communicate across well-defined interfaces and CLI surfaces.

## 2. External Dependencies & Subsystems
- Zero external heavy dependencies; platform standard library oriented.


## 3. Cross-Cutting Concerns
- **PQC Secrets Decoupling:** Cryptographic operations are isolated from application logic through FIPS 203/204/205 tools.
- **RAG & Knowledge Retrieval:** Codebase symbols and documentation chunks are vectorized using EmbeddingGemma-2 (768-d) and queried via LanceDB hybrid search.
- **Rules Synchronization:** Rules and agent contracts propagate outward from `ainish-coder` to target repositories via `--rules` deployment.
