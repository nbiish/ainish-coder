---
title: Research & Intelligence
aliases: ["research", "embeddings", "retrieval"]
tags: [ainish/wiki/research, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-11T18:50:47.621145+00:00
source_commit: 275bbff
decision_source: structural
---

# 05. Research & Intelligence — repo

## 1. Multimodal Embedding Architecture
- **Model:** `unsloth/embeddinggemma-2-GGUF` (Google DeepMind EmbeddingGemma-2).
- **Parameters:** 740M total (270M text backbone + 170M vision encoder + 300M audio encoder).
- **Output Space:** 768-dimensional normalized dense embedding space uniting text, code, images, video, and audio.
- **Matryoshka Representation Learning (MRL):** Supports lossless truncation down to 256 dimensions with mandatory L2 re-normalization.
- **Context Length:** 8,192 tokens shared across modalities.

## 2. Vector Database & Storage Engine
- **Storage:** LanceDB (columnar Arrow table format with embedded IVF-PQ / HNSW vector indexing).
- **Hybrid Retrieval:** Dense vector similarity combined with lexical BM25/FTS search.


## Related
- [[02-codebase-connections|Codebase Connections]]
- [[04-improvements-and-debt|Improvements & Debt]]
- [[README|Vault index]]

