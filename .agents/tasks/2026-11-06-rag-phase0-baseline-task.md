# Task: ainish-rag Phase 0 — measurement harness and a committed baseline

- lane: now
- branch: `feat/rag-phase-0-bench-baseline` (merged `--no-ff`, deleted)
- status: done
- plan: [`docs/rag-context-system-plan.md`](../../docs/rag-context-system-plan.md) Phase 0
- scope: `src/rag/rag.py`, `src/rag/tests/test_bench_metrics.py`, `.gitignore`,
  `.agents/rag/bench-baseline.json`, `bin/ainish-rag`

## Why

The plan cannot claim "advanced retrieval" without a before number. The existing baseline
`.agents/rag/bench-baseline.json` (saved 2026-10-12) could not serve as that floor:

1. **Saturated metric.** Only binary Recall@3 was recorded and all 3 queries passed, so the
   metric read 100%. No Phase 2 change could demonstrate an improvement against it.
2. **No embedding identity.** The live store is built with
   `openrouter/text-embedding-3-small`, while `rag.py`'s docstring and the launcher still claim
   EmbeddingGemma-2 GGUF. A backend change would have been indistinguishable from a ranking
   regression.
3. **Uncommittable.** The baseline lived under `.agents/rag/`, ignored in full at
   `.gitignore:164`, so the plan's own exit criterion was unsatisfiable.

Investigation also surfaced two defects in the engine's entry points that blocked measuring at all.

## What changed

- `bench` records nDCG@3 (exponential gain, graded relevance: 2 = labelled domain hit,
  1 = passing mention, 0 = unrelated), per-query and average injected chunk tokens, the embedding
  identity from the store fingerprint, the store row count, and the engine commit.
- `compare_to_baseline` gates on both recall and nDCG at a 90% threshold, and reports a changed
  embedding identity as **incomparable** rather than as a regression. A legacy baseline with no
  nDCG field still compares on recall alone; a baseline recorded as 0.0 does not make every later
  run "regress".
- Metric logic was factored out of the `bench` command body so it is unit-testable:
  `estimate_tokens`, `chunk_retrieval_tokens`, `graded_relevance`, `ndcg_at_k`, `bench_metrics`,
  `bench_baseline_payload`, `compare_to_baseline`, `read_index_fingerprint_identity`,
  `engine_commit`.
- `.gitignore`: `.agents/rag/` became `.agents/rag/*` plus `!.agents/rag/bench-baseline.json`.
  A directory-level ignore stops git from descending, so the exception was inert in the old form.
- `bin/ainish-rag`: `is_self` compares real paths before accepting a native-binary candidate.

## Defects found and fixed

1. **nDCG could exceed 1.0.** Normalizing a multi-hit DCG against a single ideal grade-2 hit
   produced `nDCG@3: 2.131` on the first real run. Now normalized against the ideal ordering of
   what was retrieved, and pinned by a range assertion over several grade vectors.
2. **`bin/ainish-rag` exec'd itself.** Every OS branch accepted a file named `ainish-rag` beside
   the script as the "native binary" and `exec`'d it — unbounded self-exec, no output, never
   terminates. Bit Linux, WSL, Git Bash, and the unknown-OS branch identically. Reproduced as a
   5s timeout under WSL; this is why an earlier WSL bench run produced nothing at all.

## Verification

- `py -3 -m unittest discover -s src/rag/tests -p "test_*.py"` — 71 pass (18 new).
- Real full-corpus baseline, recorded through the Python engine:

  | Metric | Value |
  |---|---|
  | Recall@3 | 1.000 (3/3) |
  | nDCG@3 | 1.000 |
  | Chunk tokens (avg/query) | 920 |
  | Avg latency | 1149 ms (remote API embeddings) |
  | Store records | 3627 |
  | Embedding identity | `api:openrouter:openai/text-embedding-3-small` |
  | Engine commit | `fab34e1` |

- `--regression` passes on a healthy run; a degraded nDCG (0.40 vs 1.00) fails; an identity change
  reports `incomparable`. All three exercised directly against the recorded baseline.
- `bin/ainish-rag --version` returns `ainish-rag 0.1.0` under both WSL and Git Bash (previously
  hung until killed).
- `scripts/test-pqc-dist.sh`: **73/73 on WSL**. On Windows Git Bash 2 assertions fail
  (`an opposite-host stamp still resolves to this checkout`, `keygen produced an identity or found
  one`) — reproduced identically at pristine `HEAD` with this work stashed, so they are
  pre-existing Windows-host defects, not regressions.

## Not done, and why

- **A second corpus (`local-router`) was not baselined.** Phase 0 names it, but that repo has 18
  uncommitted paths (a mid-flight skills refresh plus a modified deploy manifest and signature),
  which violates non-negotiable #1 for starting work there. Needs a separate cleanup pass.
- **The Rust engine was not extended.** `bench` delegates to `bin/ainish-rag.exe` whenever Python
  `lancedb` is unavailable, and that binary is stale: built 2026-10-31 while `src/rag/src/` has
  advanced to 2026-11-04, and its `--help` still lacks `verify`. Extending only `rag.py` means a
  Windows run through the launcher reports the *old* metrics. The Rust path should either be
  mirrored or the exe rebuilt; neither was in Phase 0's scope, and this must be closed before
  relying on launcher-driven benchmarks.
- **The Windows PQC store is empty (0 keys); the WSL store has 13.** The embedding key resolves
  only under WSL, so the baseline had to be recorded there. This is the host-split the contract
  warns about and is unresolved.

## Follow-ups worth a decision

1. Mirror the Phase 0 metrics into `src/rag/src/main.rs`, or rebuild `ainish-rag.exe`, so both
   engines report comparably.
2. Retire the stale "EmbeddingGemma-2" claim in `rag.py:5` and `bin/ainish-rag:4`, or make the
   docstring describe the configured provider instead of a hardcoded model.
3. Fix the two Windows-only gate failures separately; both are in `src/verify_skills.sh` /
   `pqc-secrets` territory, not the RAG engine.
