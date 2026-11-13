---
plan_format: ainish/plan/v1
slug: egm-context-prime
date: 2026-11-12
status: done
branch: feat/egm-context-prime
worktree: /Users/nbiish/code/ainish-coder-egm
task_record: .agents/tasks/2026-11-12-egm-context-prime.md
operator: question-me
---

# Retire the vector subsystem; make `--context` a Google-EGM context prime

## 1. Problem

`ainish-rag --context` is the one call `AGENTS.md` directs every agent to make. It should be the
best context prime this repository can produce. Three things stand in the way:

1. **A dead vector subsystem still costs money and latency.** `--context` is already graph-first
   (`graph_retrieve` answers from the wiki vault and `.agents/` folders; `AINISH_RAG_VECTOR_FALLBACK=1`
   only opts *in*). But ~1359 lines of Rust (`embed.rs`, `store.rs`, `ingest.rs`), a Python
   `EmbedClient`/`LanceStore` pair, three crates (`lancedb`, `arrow-schema`, `arrow-array`), and seven
   subcommands that exist only to serve them are still maintained, tested, and documented as if live.
   Every one of them requires a local GGUF model or a paid embedding provider. The operator's
   judgement: a 1M-token model plus expert database calls is cheaper and faster than that machinery.
2. **Elephant and Goldfish are prompt roles, not the EGM reviewers they claim to be.** Both run inside
   one Python process. `distinct_reviewer_requested()` is **off by default**, so the observed behaviour
   is `elephant=mimo-v2.6-pro | goldfish=mimo-v2.6-pro` — *the drafter reviewing its own draft*, which
   Google's EGM says defeats the entire point. The reviewer also performs only the middle step of
   Google's three-step Goldfish protocol.
3. **The wiki is not refreshed as part of the prime.** `--context` reads the vault but never updates
   it, so a stale vault silently becomes the retrieval corpus.

## 2. Anchor facts

Verified 2026-11-12 against `f298f21`.

| Fact | Established by |
|---|---|
| `--context` is graph-first; vectors are opt-in | `rag.py:5320-5325` — returns `wiki_graph_empty` unless `AINISH_RAG_VECTOR_FALLBACK=1` |
| `graph_retrieve` / `render_orientation_section` never call embeddings | `awk` sweep of both bodies: zero `embed`/`LanceStore` refs |
| `run_gate` takes `client`/`store` and uses neither | `rag.py:7517` signature; body has 0 references |
| `distinct_reviewer_requested()` defaults off | `rag.py:4239-4251` |
| Observed same-model self-review | this session's own `--context`: `pair: elephant=local-router:mimo-v2.6-pro \| goldfish=local-router:mimo-v2.6-pro` |
| Google Goldfish = 3 steps | [EGM plugin post](https://opensource.googleblog.com/2026/10/introducing-elephant-goldfish-model-plugin.html): comprehension check → antagonistic review → implementation-readiness go/no-go |
| Google EGM fails closed without fresh contexts | [google/elephant-goldfish-model](https://github.com/google/elephant-goldfish-model): "Goldfish reviews require fresh subagent contexts. If your agent cannot create them, EGM stops the review." |
| Vector subsystem size | `wc -l`: `embed.rs` 484, `store.rs` 383, `ingest.rs` 492 |
| `wiki` no longer requires embeddings | `--index` made opt-in in `2542e41`; `wiki --help` confirms |
| Embedding tests to retire | `test_embed_provider.py` 237, `test_embedding_identity.py` 164, `test_bench_metrics.py` 173 |

**Operator decisions (2026-11-12):**
1. **Delete** the vector subsystem outright — code, crates, and the seven vector-only subcommands.
2. **Fail closed** on reviewer separation, matching Google EGM: if a genuinely different model is
   unavailable, mark the review unavailable and say so. Never silently self-review.
3. **Full three-step Goldfish**: comprehension check → antagonistic review → implementation-readiness
   go/no-go.

## 3. Design

### 3.1 The prime is one labelled envelope with four parts

```
orientation   (code, no model)      where am I: branch, worktree, tree state, COMMS, task, plan
wiki          (code, no model)      newest vault pages + newest .agents artifacts  [the corpus]
elephant      (model call #1)       session-aware: what this session already settled
goldfish      (model calls #2..4)   fresh reader: comprehend → attack → go/no-go
```

Concatenation order is fixed and matters: `orientation` first (always true, cheapest), then `wiki`
(the evidence both reviewers read), then `elephant` (the session's reading of that evidence), then
`goldfish` (the adversarial response to the elephant's reading). A reviewer that has not seen the
evidence cannot review it; a prime that puts the critique before the material reads as an
instruction rather than an observation.

### 3.2 Reviewer separation is a precondition, not a report

`distinct_reviewer_requested()` currently makes separation opt-in and then merely *reports* whether
it happened. Invert it:

- Separation becomes the default; `AINISH_RAG_ALLOW_SELF_REVIEW=1` is the explicit, loud override.
- Before calling Goldfish, resolve both role models. If they resolve to the same id, **do not call**.
  Emit `goldfish: unavailable — reviewer resolved to the same model as the drafter (<id>); EGM
  requires a fresh reviewer`. Set `degraded: true` and name it in `degrade_notes`.
- Provenance gains `reviewer_separated: bool` and `reviewer_isolation: "distinct-model" | "unavailable"`.
  This is the honest version of the field that exists today.

Google's reasoning is the justification: a goldfish's value is that it holds *no* shared context, so
a same-model call is not a weaker review, it is a different (and misleading) thing wearing the same
label. Failing closed is the only report that cannot mislead.

### 3.3 Three-step Goldfish protocol

Each step is a separate call with a narrow instruction, all stateless, none receiving session state:

| Step | Question | Output |
|---|---|---|
| 1. Comprehension | "Restate this prime's architecture and intent in your own words." | `restatement` — if it drifts from the elephant's claim, the prime is ambiguous |
| 2. Antagonistic | "Find edge cases, hidden dependencies, logical gaps, contradictions." | `findings` — adversarial, concrete |
| 3. Readiness | "Can an implementer act on this with no further questions?" | `verdict: ready \| not-ready` + the single blocking gap |

Budget: step 1 and 2 share the goldfish cap; step 3 gets its own small cap because a verdict is
cheap. The three are concatenated into one `goldfish` section so the envelope keeps its shape, with
sub-headings so a reading agent can tell the steps apart.

If step 1 drifts (the restatement contradicts the retrieval), that is itself a finding and is
surfaced in step 2's material rather than silently dropped.

### 3.4 Wiki refresh inside `--context`

`--context` gains `--refresh-wiki` (default **off**, because it writes to the tracked vault and a
read-mostly command must not dirty the tree silently). When passed:

- Regenerate the vault via `generate_wiki` (already embedding-free; already refuses to clobber a vault
  it cannot reproduce — that guard stays).
- Run it **before** `graph_retrieve`, so retrieval reads the fresh pages, not the stale ones.
- Report `wiki: refreshed (N pages)` or `wiki: unchanged` in provenance.

The default stays off so `--context` remains safe in a dirty tree; the AGENTS.md guidance will say to
pass it at the start of a task. Making it default-on would mean every context call can rewrite seven
tracked files, which is exactly the silent-churn failure this repo has already been bitten by twice.

### 3.5 What "delete" means, precisely

Removed: `embed.rs`, `store.rs`, `ingest.rs`; `EmbedClient`, `LanceStore`, `start_server`,
`native_query_store`, `resolve_psk` and their helpers in `rag.py`; crates `lancedb`, `arrow-schema`,
`arrow-array`; subcommands `serve`, `stop`, `index`, `query`, `rerank`, `bench`, `monitor`,
`embed-provider`; `retrieval_strategy` vector branches; `AINISH_RAG_VECTOR_FALLBACK` and
`AIISH_RAG_VECTOR_*` envs; `test_embed_provider.py`, `test_embedding_identity.py`,
`test_bench_metrics.py`.

Kept: `context`, `orient`, `wiki`, `gate`, `audit`, `secrets`, `route`, `decide`, `eval`, `cleanup`,
`status`, `statusline`, `completion`. `eval` keeps its decision-graded half and loses its
vector-recall half; `gate` loses the two unused parameters.

**Migration:** a removed subcommand must fail with the reason and the replacement, not
`unrecognized subcommand`. `bin/ainish-rag` gained `PY_ONLY_SUBCOMMANDS` for exactly this problem;
the Rust CLI gets a `Removed` command group that prints "`index` was retired 2026-11-12: retrieval is
graph-first over the wiki vault. Use `ainish-rag --context`." and exits 1.

## 4. Tasks

### 4.1 Engine — `src/rag/rag.py`
- [ ] Delete `EmbedClient`, `LanceStore`, `start_server`, `resolve_psk`/PSK helpers, `native_query_store`.
- [ ] Delete vector branches in `retrieve_context`; graph-only, with the honest `wiki_graph_empty` notice.
- [ ] Delete `embed_one`/`embed_batch`/`search_vector` call sites (18 found); keep `run_gate`'s and
      `run_eval_patch`'s non-vector halves, dropping their unused `client`/`store` parameters.
- [ ] Remove the retired subparsers; add `REMOVED_SUBCOMMANDS` map producing the migration message.
- [ ] `--context`: add `--refresh-wiki`; wire wiki step before retrieval; reorder sections
      orientation → retrieval → elephant → goldfish (already the order — pin it with a test).
- [ ] Invert reviewer separation (§3.2) and implement the three-step protocol (§3.3).
- [ ] Update `CONTEXT_SECTION_CAPS` if the three-step review needs a different share; keep the
      degradation ladder order (trim retrieval → drop goldfish → drop elephant → orientation last).

### 4.2 Engine — `src/rag/src/`
- [ ] Delete `embed.rs`, `store.rs`, `ingest.rs`; drop the three crates.
- [ ] Delete the vector subcommands; add the `Removed` migration group.
- [ ] Mirror the reviewer rules so a future native build cannot silently self-review.
- [ ] `cargo build --release` + `cargo test` green.

### 4.3 Tests
- [ ] Retire the three embedding test files; keep every test whose subject survives.
- [ ] New: reviewer self-review is refused (fail closed) — same-model resolution yields
      `reviewer_isolation: unavailable` and no goldfish text.
- [ ] New: three-step protocol emits all three steps and a verdict; a drifting comprehension is
      surfaced as a finding.
- [ ] New: `--refresh-wiki` regenerates before retrieval; default does not write.
- [ ] New: removed subcommands print the migration message and exit 1.
- [ ] New: section order is orientation → retrieval → elephant → goldfish.
- [ ] Update `scripts/test-pqc-dist.sh` pins that name removed commands or the embedding path.

### 4.4 Docs
- [ ] `AGENTS.md` — the context call section names the four parts and `--refresh-wiki`. **Stay ≤160
      lines** (currently 159: this change must be net-neutral or cheaper).
- [ ] `llms.txt` — remove the vector/EmbeddingGemma descriptions; describe the EGM prime; state that
      a retired subcommand is retired, not broken.
- [ ] `.agents/plans/llms.txt` and the memory/wiki child contracts if they name embeddings.
- [ ] Regenerate the vault with the native engine so page 05 stops advertising EmbeddingGemma.

## 5. Gates

- **No embedding path remains reachable.** `grep -riE "embeddinggemma|lancedb|lance|embed_one|search_vector"`
  over `src/rag/` and `bin/` returns only historical records (`.agents/` history is grandfathered),
  never live code or live docs.
- **Self-review cannot happen silently.** With no distinct model available, `--context` reports
  `reviewer_isolation: unavailable` and `degraded: true` and emits no goldfish text. Verified by test.
- **`--context` costs nothing when it should cost nothing.** With drivers unreachable, the prime still
  returns orientation + retrieval and says why; no llama-server is started, no model is downloaded.
- `AGENTS.md` ≤160 lines.
- `bash -n` on touched scripts; `cargo test` and `pytest src/rag/tests` green.

## 6. Verification

- `pytest src/rag/tests` green, with the count reconciled against the retired embedding tests.
- `cargo test --release` green.
- `bash scripts/test-pqc-dist.sh` green; baseline recorded first so pre-existing failures are not
  misread.
- Live proof on this repo: `ainish-rag --context --task "..."` shows four labelled sections, both
  role models, `reviewer_separated`, and either a real second model or an explicit refusal.
- Live proof of the retirement: `ainish-rag index` exits 1 with the migration message.
- No llama-server process and no model download during any of the above.

## 7. Open

- **Which distinct model for Goldfish?** With `local-router/fallback-models` at the head, the
  reviewer's model is only known after the call. The plan rotates the chain for the goldfish role and
  then *verifies* the resolved id; if the chain cannot offer a different model, the review fails
  closed rather than pretending. An operator pin (`AINISH_RAG_GOLDFISH_MODEL`) is the deterministic
  fix and should be documented as the recommended setup.
- **Retiring `eval`'s recall half** changes what `--eval` measures. It becomes decision-graded only;
  that is a smaller claim, and the docs must say so rather than imply parity.
