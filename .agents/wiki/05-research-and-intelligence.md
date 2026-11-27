---
title: Research & Intelligence
aliases: ["research", "intelligence", "sources"]
tags: [ainish/wiki/research, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-27T02:01:58.015410+00:00
source_commit: 015da87
decision_source: hermes-reviewed
---
# 05. Research & Intelligence — ainish-coder

## 1. Retrieval Architecture

- **Status:** the EmbeddingGemma-2 GGUF model, its 768-d space, Matryoshka truncation, and the LanceDB store were **DELETED on 2026-11-12**, not disabled. The `src/rag/` Rust crate was **DELETED on 2026-11-19** (`2026-11-19-team.md`, `consolidates.2026-11-01.md` memories digest). There is no model to download, no dimension to configure, and no vector index to build.
- **What runs instead:** graph-first retrieval over this vault and the `.agents/` context folders, collapsed into one Python context engine at `src/context/engine.py` behind `ainish-coder --context "<input>"` (`2026-11-19-team.md`, comms digest). `ainish-context` is the launcher; `ainish-rag` is a deprecation shim only. Nodes are markdown sections; edges are `[[wikilinks]]`, markdown links, and bounded shared vocabulary (per-node edge bounds reduced 42,216 → 4,220); seeds are the task's rare terms; one hop of expansion; recency breaks ties. `KIND_INTENT` boosts named layers and forces retrieval past `skip_retrieval` (comms digest).
- **Why:** retrieval answers "which curated section explains this", not "which chunk is near this string". The vault is already curated by the agents who wrote it, so a vector index added a dependency without adding evidence — and it turned a missing key into a degraded host.

## 2. Retrieval Engine

- **Corpus:** `.agents/wiki/*.md`, `AGENTS.md`, `llms.txt`, `.agents/{comms,memories,plans,suggestions,tasks}`, `.agents/templates/`, `research/`, and the learned skills under `.agents/context-harness/skills/`. Last verified whole-corpus measurement: 164 files, 411 nodes (comms digest, 2026-11-19).
- **Cache:** `.agents/rag/wiki-graph.json`, keyed on source mtimes and on the corpus DEFINITION, so a tuning or source-set change cannot be served a stale graph.
- **Tuning:** per-repo, in `.agents/context-harness/prime-profile.json`, reported on every call as `provenance.harness`. Engine settings derive from `BASE_PROFILE` via `base_settings()`; never hand-edit the engine constants (comms digest).
- **Task records & acceptance:** `--task-record` with `--outcome ok|fail|unknown` plus `_coverage_loss_guard` bound acceptance of retrieval changes (comms digest).
- **Wiki refresh** dispatches to the native renderer or the vault format; learned skills live on one surface under `.agents/context-harness/skills/` (comms digest).

## 3. Retrieval Quality Measurement

- **Bench harness:** an nDCG/token/embedding-identity regression gate with a committed baseline was built to measure retrieval quality (suggestions digest). Gate exercised in all three states; the two Windows-only failures were proven pre-existing at pristine HEAD.
- **Open measurement gaps:** the EGM split and the direct-transport chain remain unmeasured or unlanded, as does the signing-anchor rotation (memories digest). Treat claims in those areas as provisional.

## 4. Federation & Intelligence Feeds

- A PQC-signed federation feed was stood up during 2026-11 (memories digest), with later profile cleanup work landed (`2026-11-22-14-federation-profile-cleanup.plan.md`, tasks digest). Verification of federation behavior is tracked in `2026-11-11-federation-verify-task.md` and discoverability work in `2026-11-17-13-federation-discoverability.md` (tasks/plans digests).
- **Recurring caution:** an Obsidian-vault downgrade was silently introduced and later fixed (suggestions digest) — retrieval results sourced from vault markdown must stay on the full vault format, not the downgraded one. A background pass also once clobbered a manual digest (`2026-11-21-15-background-pass-clobber.md`, suggestions digest), so any automated rewrite of retrieval artifacts needs the same protection the digest tooling now carries.

## 5. Signing & Identity in the Intelligence Path

- Signing of context artifacts moved to Python ML-DSA-65 over a 32-byte seed when the Rust crate was retired (comms digest). Identity and secret handling for these paths follow the PQC mandate in the repo contract: AES-256-GCM wrapped with ML-KEM-768 in `~/.config/pqc-secrets/secrets.bundle.json`, never plaintext in configs or logs.
- The direct-transport chain and pair-transport durability remain flagged for follow-up (`2026-11-25-18-pair-transport-durability.md`, `2026-11-25-18-local-router-chain-drift-and-health-401s.md`, suggestions).

## Sibling Pages
- [[02-codebase-connections|Codebase Connections]]
- [[04-improvements-and-debt|Improvements & Debt]]
- [[README|Vault index]]

## Related

[[01-architecture]], [[02-codebase-connections]], [[03-security-and-governance]], [[04-improvements-and-debt]], [[06-marketing-and-positioning]]
