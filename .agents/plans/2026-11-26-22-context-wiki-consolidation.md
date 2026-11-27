---
plan_format: ainish/plan/v1
slug: context-wiki-consolidation
date: 2026-11-26
status: done
branch: feat/context-wiki-consolidation
worktree: /Users/nbiish/code/ainish-coder-worktrees/feat-context-wiki-consolidation
task_record: .agents/tasks/2026-11-26-22-context-wiki-consolidation.md
integration: new-pr
operator: nanoboozhoo
---

# Plan: Multi-Batch Consolidation Merge Fix, Hermes Wiki Review/Compilation, and Live `.agents/` Consolidation

## 1. Objective

Following the merge of PR #19 (`015da87`), complete and live-verify the end-to-end context consolidation and wiki-priming system:

1. **Multi-batch merge verification fix:** When a folder has many aged records (e.g., `.agents/plans/` or `.agents/tasks/` with 25+ aged files), `_digest_in_chunks` merges verified partial digests. Review the merged digest against the verified `partials` (not `payload[:10]`, which caused false fidelity rejections on records #11+), while enforcing in code that the 3 chronologically newest original files are NEVER fed to consolidation agents.
2. **Hermes-gated `.agents/wiki/` review, edit, and compilation:** Add `run_wiki_review(repo_root)` using `consolidate-elephant` (drafter) + `consolidate-goldfish` (fidelity gate) + deterministic code guards (YAML frontmatter + `ainish/wiki` tags + `[[wikilinks]]` + banned-retired-subsystem check + verbatim `ledger.md` preservation without touching `ledger.md`/`ledger.sig`), followed by recompiling `.agents/rag/wiki-graph.json`. Wire it into `run_context_consolidate` (after folder consolidation or when wiki `source_commit` lags `HEAD`), `run_context_command` (`--refresh-wiki` + compiled wiki-graph provenance), and `ainish-coder --context-wiki-review`. Update `generate_wiki()` templates to drop deleted `LanceDB`/`EmbeddingGemma-2` claims and emit Obsidian vault frontmatter + `[[wikilinks]]`.
3. **Live execution on this repository's `.agents/` folders and wiki:**
   - Run the real 4-profile Hermes consolidation panel across all 5 folders (`.agents/{comms,memories,plans,suggestions,tasks}`), feeding ONLY files outside the 3 newest originals (+ superseded `DIGEST-*.md` files), leaving 3 newest originals + 1 rolling digest per folder.
   - Run the real Hermes wiki review/edit + wiki-graph compilation on `.agents/wiki/`.
   - Run live `ainish-coder --context "<input>"` to emit the compiled context prime (orientation + compiled wiki-graph retrieval + Hermes `context-elephant` + Pi `goldfish` 3-step review + consolidation/wiki provenance).

## 2. Threat Model & Constraints

- **Assets:** `.agents/{comms,memories,plans,suggestions,tasks}` coordination history; `.agents/wiki/` Obsidian vault + ML-DSA-65 signed `ledger.md`/`ledger.sig`; PQC secrets bundle (untouched).
- **Controls:**
  - Protected retention enforced in code: the 3 chronologically newest dated originals per folder are explicitly excluded from `payload` and never unlinked.
  - Digest-before-delete + unanimous 3-member Hermes panel (`consolidate-goldfish`, `consolidate-archivist`, `consolidate-structural`) enforced before any deletion.
  - Wiki review fails closed: a page failing deterministic structure/vault-preservation checks or Hermes `consolidate-goldfish` fidelity review is NEVER overwritten; `ledger.md` and `ledger.sig` are read-only and never modified.
  - No secrets in prompts, wiki pages, digests, logs, or tests. `AGENTS.md` and `LICENSE` untouched.

## 3. Checklist

- [x] Fix `_digest_in_chunks` merge-step panel review (`partials` instead of `payload[:10]`) and add explicit `protected_set` defense-in-depth exclusion in `run_context_consolidate`.
- [x] Update `generate_wiki()` templates (graph-first Python engine, Obsidian frontmatter + `[[wikilinks]]`, `ledger.md` preserved/spliced) and implement `run_wiki_review()` + `wiki_is_stale()` + `context-wiki-review` subcommand + `bin/ainish-coder --context-wiki-review` + `run_context_consolidate` & `run_context_command` integration.
- [x] Update `src/help.sh`, `llms.txt`, `src/context/tests/test_context_injection.py`, and `src/context/tests/test_wiki_graph.py`.
- [x] Run live Hermes consolidation across all 5 `.agents/{comms,memories,plans,suggestions,tasks}` folders in this worktree and verify 3 newest originals + 1 rolling digest per folder.
- [x] Run live Hermes wiki review/edit + wiki-graph compilation on `.agents/wiki/` in this worktree.
- [x] Run live `ainish-coder --context "<input>"` in this worktree and capture the full compiled context prime output.
- [x] Verify unit tests, commit cleanly, push branch, open PR to `main`, confirm green CI.
