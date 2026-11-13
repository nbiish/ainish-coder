# EGM context prime; retire the vector subsystem

- **status:** done
- **branch:** `feat/egm-context-prime`
- **plan:** `.agents/plans/2026-11-12-01-egm-context-prime.md`
- **worktree:** `/Users/nbiish/code/ainish-coder-egm`
- **operator ask:** "clean up old embeddings content that requires a local model or provider embedding
  models. It slows our context down and costs too much compared to using expert database calls with
  modern one million context models. `ainish-rag --context` should use two subagents within itself
  aside from activating the wiki update for best context generation. There should be an elephant and
  goldfish agent that review each of their designated material according to Google's latest elephant
  and goldfish model publishings; but modified for our ainish-rag --context tooling so that they
  concatenate their responses alongside the wiki agent output collectively as an expertly crafted
  context prime."
- **operator decisions:** delete the vector subsystem outright; fail closed when the reviewer cannot
  be a distinct model (matching Google EGM); full three-step Goldfish protocol.
- **scope:** `src/rag/rag.py`, `src/rag/src/{main.rs,wiki.rs}`, deletion of
  `src/rag/src/{embed.rs,store.rs,ingest.rs}`, `src/rag/Cargo.toml`, `src/rag/tests/`,
  `scripts/test-pqc-dist.sh`, `AGENTS.md`, `llms.txt`, `.agents/wiki/` (regenerated)

## What was found

1. **`--context` was already graph-first.** `retrieve_context` returns `wiki_graph_empty` unless
   `AINISH_RAG_VECTOR_FALLBACK=1`, so the vector subsystem was already unreachable by default while
   still being maintained, tested, and documented. 407 embedding references in `rag.py`, 224 in
   `main.rs`, 1359 lines of Rust across three modules, three crates, and eight subcommands.
2. **The EGM pair was self-reviewing.** `distinct_reviewer_requested()` defaults to False, so this
   session's own context call reported `elephant=mimo-v2.6-pro | goldfish=mimo-v2.6-pro` — the
   drafter reviewing its own draft. Google's EGM states the opposite requirement and fails the review
   when fresh contexts are unavailable.
3. **Only one of Google's three Goldfish steps existed** (the antagonistic review); the comprehension
   check and the implementation-readiness verdict were missing.
4. **`run_gate` accepted `client`/`store` and used neither** — dead parameters kept alive only
   because the embedding types were still imported.

## What changed

1. **The vector subsystem is deleted, not disabled.** `embed.rs`, `store.rs`, `ingest.rs` removed
   (1,359 lines) with the `lancedb`/`arrow-schema`/`arrow-array` crates; `EmbedClient`, `LanceStore`,
   `start_server`/`stop_server`, `native_query_store`, the provider-identity helpers, and
   `run_eval_patch` removed from `rag.py`; eight subcommands (`serve`, `stop`, `index`, `query`,
   `rerank`, `bench`, `monitor`, `embed-provider`) and `service` retired in both engines. Each retired
   verb still *parses* and prints what replaced it, then exits 1 — `unrecognized subcommand` reads as
   a typo, not a deliberate removal. Three embedding test files deleted; `retrieve_context` is
   graph-only.
2. **Reviewer independence is now a precondition, per Google's EGM.** `distinct_reviewer_requested`
   was inverted: separation is the default and `AINISH_RAG_ALLOW_SELF_REVIEW=1` / `--allow-self-review`
   is the recorded downgrade. `plan_reviewer_model` resolves the reviewer *before* spending any calls
   and refuses when nothing distinct exists. Provenance reports `reviewer_isolation`,
   `reviewer_separated`, and `reviewer_steps`; the envelope's `pair:` line says "independent reviewer"
   or "review refused" in words.
3. **Three-step Goldfish.** Comprehension check → antagonistic review → implementation-readiness
   verdict, each a separate stateless call. The comprehension output is fed into the antagonistic
   step, because drift there is the ambiguity signal. A step returning nothing is named in the
   section reason rather than silently dropped.
4. **`--context --refresh-wiki`** regenerates the vault before retrieval (off by default; it writes
   tracked files).
5. **Survivors preserved.** `scrub_sensitive_content` (a security control) and `is_ignored_path` moved
   to a new `scrub.rs`; `read_or_init_privacy_budget` kept (the DP ledger is still audited);
   `SearchHit` became a local rerank contract in `decision.rs`; the gate kept its diff security checks
   (credential canary, Trojan Source) and lost only the embedding-anchored score.
6. Docs: `AGENTS.md` context section rewritten to the four-part prime and the reviewer rule (160 lines,
   at the gate); `llms.txt` vector sections marked deleted and the pair/protocol sections rewritten.

## Verification

| Gate | Baseline | After |
|---|---|---|
| `scripts/test-pqc-dist.sh` | 259 PASS | **277 PASS** |
| `src/rag` pytest | 189 passed | **135 passed** (54 retired with the vector tests) |
| `cargo test --release` | 59 passed | **55 passed** (4 were vector-only) |
| `cargo build --release` | green | green |
| `ainish-rag index` (both engines) | worked | exits 1 with the retirement message |
| `--context` with same-model pins | silently self-reviewed | **refused**, reason named, `degraded: true` |
| `--context` with distinct models | 1 of 3 goldfish steps | **all 3 steps**, no errors |

Live proof of the refusal is in the COMMS entry: `goldfish=refused | reviewer pin ... resolves to the
same model the drafter used`.

## Expected first failure if this is wrong

The reviewer being *too* strict: `plan_reviewer_model` refuses when the drafter's model cannot be
identified (an unroutable `local-router` head) or when every chain step resolves to it. On a
single-provider host that means no review at all rather than a same-model one — which is the
operator's chosen trade (EGM stops the review), but it will look like a regression to anyone
expecting a goldfish section every time. The `pair:` line and `reviewer_isolation` are what
distinguish "refused on purpose" from "broken".
