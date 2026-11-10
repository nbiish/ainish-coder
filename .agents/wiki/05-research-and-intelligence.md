---
title: "05. Research & Intelligence"
aliases:
  - "05 Research and Intelligence"
  - "Research and Intelligence"
tags:
  - agents/wiki
  - research
generated: true
---

# 05. Research & Intelligence — ainish-coder-context-prime

## See also

- [[01 Architecture|System Architecture]]
- [[02 Codebase Connections|Codebase Connections and Symbols]]
- [[03 Security and Governance|Security and Governance]]
- [[04 Improvements and Debt|Improvements and Technical Debt]]
- [[06 Marketing and Positioning|Marketing and Positioning]]
- [[ledger|Operator Ledger]]

## 1. Multimodal Embedding Architecture
- **Model:** `unsloth/embeddinggemma-2-GGUF` (Google DeepMind EmbeddingGemma-2).
- **Parameters:** 740M total (270M text backbone + 170M vision encoder + 300M audio encoder).
- **Output Space:** 768-dimensional normalized dense embedding space uniting text, code, images, video, and audio.
- **Matryoshka Representation Learning (MRL):** Supports lossless truncation down to 256 dimensions with mandatory L2 re-normalization.
- **Context Length:** 8,192 tokens shared across modalities.

## 2. Vector Database & Storage Engine
- **Storage:** LanceDB (columnar Arrow table format with embedded IVF-PQ / HNSW vector indexing).
- **Hybrid Retrieval:** Dense vector similarity combined with lexical BM25/FTS search.
