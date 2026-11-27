# Task: Multi-Batch Consolidation, `consolidates.{naming}.md` ACP/AHP Schema, Hermes Wiki Review/Compilation, and Live Execution

- lane: now
- branch: `feat/context-wiki-consolidation`
- worktree: `/Users/nbiish/code/ainish-coder-worktrees/feat-context-wiki-consolidation`
- status: done
- plan: `.agents/plans/2026-11-26-22-context-wiki-consolidation.md`
- scope: `src/context/engine.py`, `bin/ainish-coder`, `src/help.sh`, `llms.txt`, `src/context/tests/test_context_injection.py`, `src/context/tests/test_wiki_graph.py`, `.agents/{comms,memories,plans,suggestions,tasks}/`, `.agents/wiki/`
- compat: canonical consolidated filenames use `.agents/{folder}/consolidates.{naming}.md` (`schema: consolidates.{naming}.md`); legacy `DIGEST-*.md` files remain recognized for absorption/removal and orientation exclusion; adds `ainish-coder --context-wiki-review` and `--review-wiki`
- objective: Merge PR #19, adopt the `.agents/{folder}/consolidates.{naming}.md` ACP/AHP schema, fix multi-batch merge verification + greedy batch packing + surgical retries + worktree root resolution for `--context`, implement Hermes-gated `.agents/wiki/` review/edit + graph compilation, execute live across all 5 `.agents/` folders and `.agents/wiki/`, and verify the live `ainish-coder --context` prime.

## What Changed & Live Results (2026-11-26 / 2026-11-27 UTC)

1. **PR #19 merged into `origin/main` (`015da87`)** per operator authorization.
2. **Engine hardening (`src/context/engine.py`, `bin/ainish-coder`, `src/help.sh`, `llms.txt`):**
   - Adopted canonical `.agents/{folder}/consolidates.{naming}.md` schema (`CONSOLIDATION_DIGEST_PREFIX = "consolidates."`, `schema: consolidates.{naming}.md`), while recognizing legacy `DIGEST-*` files for absorption and orientation exclusion (`_is_digest_name`).
   - Replaced uniform average batching with `_pack_consolidation_batches` (greedy 18K char / max 4 items), added surgical gap-fix retries (`previous_draft` fed back, up to 3 attempts), fixed multi-batch merge review to inspect verified `PARTIAL-*` summaries instead of `payload[:10]`, added explicit `protected_set` defense-in-depth exclusion so the 3 newest originals are never fed to consolidation agents, and gated `pi` fallback in `consolidation_call` to missing/unprovisioned Hermes (or `AINISH_CONSOLIDATE_PI_FALLBACK=1`).
   - Fixed `main()` `context` dispatch to pass `_learned_root(repo_root)` so worktree callers retrieve, attach, consolidate, and review their own worktree instead of stale `main` files.
   - Updated `generate_wiki()` templates (removing retired `LanceDB`/`EmbeddingGemma-2`/`src/rag` active references while preserving Obsidian frontmatter, `[[wikilinks]]`, and verbatim `ledger.md`/`ledger.sig`), implemented Hermes-gated `run_wiki_review()` + `wiki_status()` + `.agents/rag/wiki-graph.json` compilation, and wired `--context-wiki-review` / `--review-wiki`.
3. **Live consolidation across all 5 folders (100% `transports: ["hermes"]`, zero fallback):**
   - `.agents/comms/`: `6 -> 3` originals + `consolidates.comms-02.md` (all 3 aged originals + 2 legacy `DIGEST-comms-*` consolidated).
   - `.agents/memories/`: `15 -> 3` originals + `consolidates.2026-11-01.md` (all 12 aged originals + 4 legacy `DIGEST-memories-*` consolidated).
   - `.agents/plans/`: `32 -> 3` originals + `consolidates.2026-11-02.md` (all 29 aged originals + legacy `DIGEST-plans-2026-11.md` consolidated).
   - `.agents/suggestions/`: `8 -> 3` originals + `consolidates.2026-11-01.md` (all 5 aged originals + 2 legacy `DIGEST-suggestions-*` consolidated).
   - `.agents/tasks/`: `32 -> 3` originals + `consolidates.2026-11-01.md` (all 29 aged originals + legacy `DIGEST-tasks-2026-11.md` consolidated; plus this new closeout task record).
4. **Live `.agents/wiki/` review & compilation:**
   - `01-architecture.md`, `02-codebase-connections.md`, `03-security-and-governance.md`, `05-research-and-intelligence.md`, `06-marketing-and-positioning.md`, and `README.md` reviewed/approved by Hermes (`consolidate-elephant` + `consolidate-goldfish`); `04-improvements-and-debt.md` cleaned with verbatim `ledger.md` splice preserved (`ledger.md` and `ledger.sig` untouched); compiled `.agents/rag/wiki-graph.json` (`370 nodes / 3,712 edges`).
5. **Live `ainish-coder --context` prime (worktree-rooted):**
   - Exit 0, `degraded: false`, `notes: []`, sections `['orientation', 'retrieval', 'elephant', 'goldfish']`, `elephant=hermes:context-elephant`, `goldfish=pi:local-router/fallback-models` (all 3 EGM steps `comprehension`, `antagonistic`, `readiness` true), all 5 folders verified at `originals: 3, digests: 1, candidates: 0, needs_consolidation: false`.

## Verification Evidence

- `python3 -m py_compile src/context/engine.py src/context/tests/test_context_injection.py src/context/tests/test_wiki_graph.py` + `bash -n bin/ainish-coder src/help.sh`: pass.
- `AINISH_RAG_NO_PQC=1 python3 -m unittest src/context/tests/test_context_injection.py src/context/tests/test_wiki_graph.py`: **140/140 OK**.
- `AINISH_RAG_NO_PQC=1 python3 -m unittest discover -s src/context/tests -p "test_*.py"`: **177 tests, 1 pre-existing failure** (`test_shared_rules_file_is_loaded_and_strip_ansi` in `test_gate_ready.py`; down from 3 pre-existing failures after aligning `test_wiki_graph.py`).
