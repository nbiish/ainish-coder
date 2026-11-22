---
title: Research & Intelligence
aliases: ["research", "embeddings", "retrieval"]
tags: [ainish/wiki/research, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-13T01:02:49.078185+00:00
source_commit: 2225493
decision_source: structural
---

# 05. Research & Intelligence — ainish-coder

## 1. Retrieval Architecture

- **Status:** the EmbeddingGemma-2 GGUF model, its 768-d space, Matryoshka truncation, and the LanceDB
  store were **DELETED on 2026-11-12**, not disabled. There is no model to download, no dimension to
  configure, and no vector index to build.
- **What runs instead:** graph-first retrieval over this vault and the `.agents/` context folders.
  Nodes are markdown sections; edges are `[[wikilinks]]`, markdown links, and bounded shared
  vocabulary; seeds are the task's rare terms; one hop of expansion; recency breaks ties.
- **Why:** retrieval answers "which curated section explains this", not "which chunk is near this
  string". The vault is already curated by the agents who wrote it, so a vector index added a
  dependency without adding evidence — and it turned a missing key into a degraded host.

## 2. Retrieval Engine

- **Corpus:** `.agents/wiki/*.md`, `AGENTS.md`, `llms.txt`, `.agents/{comms,memories,plans,suggestions,tasks}`,
  `.agents/templates/`, `research/`, and the learned skills under `.agents/context-harness/skills/`.
- **Cache:** `.agents/rag/wiki-graph.json`, keyed on source mtimes and on the corpus DEFINITION, so a
  tuning or source-set change cannot be served a stale graph.
- **Tuning:** per-repo, in `.agents/context-harness/prime-profile.json`, reported on every call as
  `provenance.harness`. Never hand-edit the engine constants.

## Related
- [[02-codebase-connections|Codebase Connections]]
- [[04-improvements-and-debt|Improvements & Debt]]
- [[README|Vault index]]

