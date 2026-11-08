# Task: verify the system wiring end to end

- lane: now
- branch: `chore/verify-system-wiring` (worktree `D:\Code\ac-verify`)
- status: done
- scope: `src/rag/rag.py`, `src/rag/tests/test_context_injection.py`, `.agents/canonical/`, `.agents/audit/`

## Verdict

**The wiring is correct. Retrieval is blind — and the cause is a missing credential, not a defect.**

Every layer answered except vector search.

| Layer | Result |
|---|---|
| Decision model (`route`) | Works — local-router, 0.9–1.6 s, real strategy and route-derived budget. Independent of embeddings. |
| The documented interaction (`--context`) | Works — exit 0, all four sections, provenance naming driver model, route source, commit |
| Never-block rule | Works — retrieval unavailable still exits 0, `degraded: true`, fallback labelled |
| Hybrid vector retrieval | **Zero hits** — HTTP 401 from the embedding provider |

## The failure, precisely

The embedding provider is pinned to OpenRouter `api` (`openai/text-embedding-3-small`) and **no key
resolves**. Both the Python engine and the compiled engine fail with `401 Unauthorized`. The
3,627-record store is intact and in that vector space.

**Falling back to local EmbeddingGemma would be worse than failing**: the store was built with
`text-embedding-3-small`, local Gemma vectors are a different space, and mixed-space retrieval returns
confidently wrong neighbours rather than an error. The engine correctly refuses.

To restore retrieval: put a key back — `LOCALROUTER_OPENROUTER_API_KEY` or `OPENROUTER_API_KEY` — via
`pqc-secrets`, or pin a provider whose key exists. Do **not** switch to local embeddings without
reindexing the store.

## Defect found and fixed

`NativeQueryStore.search` caught every failure and returned an empty list, so `retrieve_context`
reported a **401 as `native_engine_empty (no_store)`**. That sends an operator hunting for a missing
index when the index is fine and the credential is gone — two completely different fixes.

Added `search_with_reason(query, limit) -> (hits, reason)`, with a reason on every early return:
no binary, non-zero exit (carrying the engine's own stderr), no output, no JSON array, no hits.
`search` delegates and keeps its old shape, so existing callers are unaffected.

The note now reads:

```
retrieval via files (no_store; native engine: native engine exited 1:
  [rag:embed-provider] No API key resolved for openrouter …)
```

## Two things to report rather than fix

**The PQC store was rewritten ~20 times between 19:55 and 20:05 UTC** and now holds one key
(`LOCALROUTER_TEST_VENDOR_API_KEY`) where it previously resolved 24. Both repo test suites are
correctly sandboxed (`PQC_CONFIG_DIR` / `PQC_SECRETS_DIR` are honoured with the same precedence), so
this is not caused by them. It coincides with the other tool's `wtf` work on this machine. I have not
attributed it further.

**Your cleanup removed historical `.agents/comms`, `.agents/tasks`, and `.agents/suggestions` files.**
167 tests and 158 gate assertions still pass, so nothing depended on them.

## Verification

- `py -m unittest discover -s src/rag/tests` — **167 pass** (3 new: missing binary, non-zero exit
  surfacing the engine's stderr, and `search` keeping its list shape).
- `bash scripts/test-pqc-dist.sh` — **158/158**.
- Live `--context` returns four sections, exit 0, with an accurate degrade note.
- Both engines confirmed to fail with **401**, not an empty store.
- `ainish-rag audit verify` after re-signing.

## Not done, and why

- **No key was restored.** That is an operator credential decision, not something to infer; a wrong
  guess would silently change the embedding space.
- **No live retrieval verification is possible** until a key exists, so hybrid search, decision
  reranking on real hits, and CRAG corrective expansion remain verified only by unit tests right now.
