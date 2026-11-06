# Plan: ainish-rag as the context-engineering system for deployed agents

Status: proposal — for execution in a new chat
Author: written 2026-11-06 after an audit of `src/rag/rag.py` (6,861 lines), `bin/`, and `.agents/`
Scope: `ainish-rag` engine, its decision/transport layer, a new Elephant+Goldfish injection
pipeline, and the two-command agent surface

---

## 1. Read this first: what actually exists

The audit matters more than the ambition, because most of the plan below is *not* greenfield and
some of the request is already built. Concretely:

| Capability | State today | Evidence |
|---|---|---|
| Hybrid vector store | **Exists** | LanceDB + EmbeddingGemma-2 GGUF, 768-d (`rag.py:1804`, `:29`) |
| Two-stage decision rerank | **Exists** | `rerank` → `rerank_via_jev` → `rerank_local` (`:3209`, `:3219`, `:3301`) |
| Typed decision API | **Exists** | `noul`/`choice`/`score` batches, `_post_decisions` (`:2974`), envelope `answers` (`:2942`) |
| Adaptive routing | **Exists** | 5 calibrated questions → `derive_retrieval_strategy` (`:2698`) |
| Corrective expansion (CRAG) | **Exists** | `evaluate_context_sufficiency` (`:2739`), `extract_corrective_expansion_terms` (`:2762`) |
| Transport failover | **Partial** | order is `local-router → openrouter → jev → local-model` (`:2674-2694`). The router itself already reports `order: ["openrouter","zenmux"]` for decisions, but the engine's own stage list has **no zenmux stage** — so engine-level failover cannot reach ZenMux directly |
| Living wiki + signed ledger | **Exists** | `generate_wiki` (`:2232`), `append_wiki_note_and_sign` (`:2136`), bidirectional resolutions (`:2212`) |
| Context injection | **Partial** | `orient --inject` emits a primer; it is **not** a two-agent pipeline |
| Elephant/Goldfish | **Docs only** | `.agents/skills/context-orchestration/SKILL.md` is a *human procedure*; `bin/egm-check.sh` only greps headings. No code, no model calls |
| Generative driver model | **Absent** | **No `chat/completions` call anywhere in the engine.** Every model call is a typed decision or an embedding |
| Self-maintaining index | **Absent** | `index` is a full scan with optional `--watch`; no delta, no autonomous curation |

Two facts drive the whole plan:

1. **There is no generative path in the engine.** Elephant and Goldfish as described — an agent that
   "modifies/adds to the initial prompt injection" and a reviewer that "adds its unfiltered
   addition" — require *text generation*, not calibrated probabilities. That is a new subsystem, not
   a flag on an existing one.
2. **The two-command surface does not exist yet.** The engine exposes **22 top-level subcommands**
   (33 including nested `audit`/`service`), verified from the parser (`grep 'sub\.add_parser'`).
   The plan has to *hide* them behind two verbs rather than add a third way to use them.

---

## 2. Goals and non-goals

### Goals

1. Two agent-facing commands only: **one to build/refresh** the repo's knowledge, **one to get
   context** for the current task.
2. Context returned is *engineered*: hybrid retrieval, decision rerank, corrective expansion, plus
   Elephant (session-aware) and Goldfish (stateless) additions concatenated into one injection.
3. Model tiering that degrades gracefully: `local-router → openrouter → zenmux → local-model`,
   for both decisions and the driver model.
4. Every retrieval/decision technique chosen is backed by a citable result, recorded next to the
   code that implements it — no technique ships on vibes.
5. `AGENTS.md` stays small: a short pointer to `.agents/**` plus the two commands.

### Non-goals

- Not a chat product. The engine returns context, not conversation.
- Not replacing the agent harness's own context management.
- Not "self-improving" in the sense of mutating its own code or prompts unsupervised. Curation of
  *content* (what to index, merge, evict) is in scope; the engine editing its own behaviour is not.
- Not removing existing subcommands. They become the internal surface behind the two verbs.

---

## 3. The honest risk register (read before estimating)

These are the reasons this plan is phased rather than delivered whole.

| Risk | Why it matters | Mitigation |
|---|---|---|
| **Driver-model latency.** Two generative passes per context call, each up to a network round trip | A context tool slower than just reading files will not be used | Budget hard: ≤1.5s local-router, ≤4s remote; degrade to retrieval-only. Phase 4 adds caching |
| **"Self-improvement" is unbounded work.** Autonomous re-index/merge/evict can thrash, corrupt the store, and burn tokens | This is the most failure-prone part of the request | Phase 3 delivers *bounded* curation: fixed rules engine + one decision call + a receipt per action. No free-form autonomy |
| **Research claims are easy to overstate.** "Proven RAG improvements" is a high bar | Shipping a technique that doesn't generalize wastes effort and erodes trust | Phase 1 produces a citations file with the *effect measured*, including negative results |
| **Injection bloat.** Elephant + Goldfish + retrieved chunks + wiki can exceed the agent's budget | A 40k-token injection defeats the purpose | Token-budgeted assembly with per-section caps and measured compression; Phase 0 sets the ceiling |
| **Decision-model drift.** A calibrated `noul` that is wrong is worse than a keyword match, because it looks authoritative | Silent quality regression | `source` is always surfaced; `eval` faithfulness gate runs in CI; a decision fixture set pins behaviour |
| **WSL/Windows interop.** Already caused one SIGTTIN hang in this repo | New engine calls will inherit the same trap | Every new subprocess gets `stdin=/dev/null`; test matrix includes WSL |

---

## 4. Phases

Each phase is independently shippable and leaves the system working. Later phases assume earlier
ones landed.

### Phase 0 — Inventory and baselines (no behaviour change)

**Why:** We cannot claim "advanced" without a before number.

- Freeze a measurement harness: `bench --regression` already exists (`:5349`); extend it to record
  Recall@k, nDCG, injection token count, and latency per query, and persist a baseline file checked
  into `.agents/rag/bench-baseline.json`.
- Pick the corpus: this repo plus one real target (`local-router`, already enrolled).
- Record **current** numbers. Everything later is compared to these.

**Exit criteria:** baseline JSON committed; a single command reproduces it.
**Deliverable:** `.agents/rag/bench-baseline.json` + a short results table in the plan's appendix.

**Status: DONE for this repo** (`138a7f3`, see `.agents/tasks/2026-11-06-rag-phase0-baseline-task.md`).
Harness records nDCG@3, chunk tokens, embedding identity, store rows, and engine commit; the
baseline is committed via a targeted `.gitignore` exception. Three preconditions had to be fixed
first, and they were not visible from the audit:

1. `.agents/rag/` was ignored in full, so "baseline committed" was unsatisfiable. A directory-level
   ignore also blocks a child exception, hence `.agents/rag/*` plus one `!` rule.
2. Recall@3 was saturated at 100% on the only three queries, which is a ceiling, not a floor.
3. `bin/ainish-rag` could exec itself on any host missing its preferred binary — which is why a WSL
   bench run silently produced nothing.

**Still open before Phase 0 is closed across both repos:**

- `local-router` is not baselined: it has 18 uncommitted paths, which blocks starting work there.
- `bench` delegates to `bin/ainish-rag.exe` when Python `lancedb` is absent, and that binary is
  stale (built 2026-10-31 vs source at 2026-11-04). A launcher-driven Windows benchmark therefore
  still reports the **old** metrics. Mirror the harness into `src/rag/src/main.rs` or rebuild.
- The embedding key resolves only under WSL (13 keys there, 0 in the Windows PQC store), so the
  baseline was recorded on the WSL host. Resolve the host split before treating numbers as
  comparable across machines.

---

### Phase 1 — Evidence dossier (decides Phase 2's content)

**Why:** You asked for proven, not hype. This phase is the gate.

- Build `docs/rag-evidence.md`: one row per technique we intend to use, with **paper, the specific
  claim measured, the effect size reported, and whether it replicates**.
- Candidate rows to verify (do not assume — verify): hybrid dense+sparse fusion; cross-encoder /
  LLM-judge reranking; query rewriting / HyDE; CRAG-style corrective retrieval; contextual chunk
  enrichment (prepending document context to chunks); parent-document / small-to-big retrieval;
  Recursive Language Models-style delegation for large contexts; "agentic RAG" loops.
- Mark each: **Adopt** (strong, replicated) / **Trial** (promising, measure locally) / **Reject**
  (doesn't replicate, or cost outweighs effect). Negative results are a deliverable, not a failure.
- Explicitly evaluate the Elephant+Goldfish premise against literature on **fresh-context
  review** and **critique-then-revise**; record whether the two-agent split has published support
  or is our own design hypothesis. If it is a hypothesis, say so in the code and the docs.

**Exit criteria:** every technique in Phase 2 traces to a row; anything unproven is labelled Trial
and gets an A/B in Phase 2. No technique ships on "it sounds better".
**Deliverable:** `docs/rag-evidence.md` (public-facing evidence, not an internal note).

---

### Phase 2 — Retrieval quality to the evidence standard

**Why:** Retrieval is the floor. Generation on top of bad retrieval is wasted tokens.

- Implement only the **Adopt** rows; gate **Trial** rows behind env flags and measure them against
  the Phase 0 baseline on the real corpus.
- Highest-expected-value items, in order:
  1. **Contextual chunk enrichment** before embedding (prepend a short synthesized header to each
     chunk). Cheap, one-time index cost, typically large recall gain.
  2. **Small-to-big / parent-document** retrieval (retrieve small, return the enclosing block).
  3. **Sparse+dense fusion** if the store supports it; otherwise a lexical prefilter.
  4. Keep the existing decision rerank; A/B it against a plain cross-encoder to confirm the
     decision-model approach actually beats the cheaper option on our corpus.
- **Incremental indexing** (needed by Phase 3): content-hash manifest so `index` re-embeds only
  changed chunks. Today it is a full scan (`idx_p`, `:5278`).

**Exit criteria:** Recall@k and nDCG exceed baseline on the fixed corpus, with the delta recorded;
`index` is incremental and idempotent.
**Deliverable:** improved engine + numbers.

---

### Phase 3 — Bounded self-maintenance (the "own agent" part, scoped honestly)

**Why:** This is the request's highest-risk item, so it gets a hard boundary.

What "self-maintaining" means here — **deterministic rules decide, one decision call ranks, every
action leaves a receipt**:

- **Detect:** content-hash manifest diff → new / changed / deleted files; a staleness signal
  (age × query miss rate) for existing chunks.
- **Decide:** a small typed `choice` batch ranks *candidate maintenance actions* (re-embed,
  merge duplicates, split oversized chunk, evict stale, promote to wiki). The model ranks only;
  thresholds and side effects stay in code.
- **Act:** apply through the existing signed-receipt path (`append_wiki_note_and_sign`). Dry-run
  by default; `--apply` to mutate.
- **Guard:** every action is reversible (evictions go to a tombstone, not a delete); a runaway guard
  caps actions per run and per day.

**Explicitly out of scope:** the engine rewriting its own prompts, its own code, or its own
technique selection without a human-visible receipt.

**Exit criteria:** a full maintenance cycle on the real corpus produces a receipt chain that
`ainish-rag audit verify` validates; dry-run output is reviewable; the runaway cap is tested.
**Deliverable:** `ainish-rag maintain [--dry-run|--apply]`.

---

### Phase 4 — The Elephant + Goldfish injection pipeline (new subsystem)

**Why:** This is the actual product surface, and it needs a generative path that doesn't exist.

**4a. Driver model.** New `driver` transport layer mirroring the decision layer:
`local-router → openrouter → zenmux → local-model`, with the same `source` discipline and hard
timeouts. Reuses `_first_env` / PQC key resolution; **never** logs keys.

Provider tier order and model ids are **verified live** (2026-11-06) and recorded in
`local-router/docs/driver-models.md`:

| Tier | Model id | Status |
|---|---|---|
| local-router → OpenRouter | `openrouter-deepseek-v4.1-flash-1017` | responds, routes to `deepseek/deepseek-v4.1-flash-1017` |
| local-router → ZenMux | `zenmux-deepseek-v4.1-flash` | responds, routes to `deepseek/deepseek-v4-flash` family |
| local-model | `…-lightning-30b-a3b-gguf-mxfp4_moe` | **offline today** (Unsloth Studio closed) |

**Do not invent `latest` aliases.** Verified: `deepseek-v4.1-flash-latest`,
`openrouter-deepseek-v4.1-flash-latest` and `zenmux-deepseek-v4.1-flash-latest` all return **HTTP
200 with `routed=auto`** — the generic fallback chain, not the requested model. The `~`-prefixed
`-latest` rows in the router registry are display aliases stripped by `normalizeModelAlias`, not
callable ids. So the driver **must compare `response.model` to the requested id** and treat a
mismatch as degraded; a 200 alone proves nothing.

Two constraints that must shape the implementation, not just the docs:

- **`deepseek-v4.1-flash` is a reasoning model.** With `max_tokens: 16` it returns `content: ""` and
  spends all 16 tokens on reasoning; at 512 it answers normally. Every driver call must budget
  reasoning *plus* answer, and must not treat empty content as a transport error — that would
  mis-diagnose a budget problem as a provider outage.
- **NVFP4 Lightning cannot run here.** `llama-quantize --help` on this build (`0.8.0-dev, 7e2fea0`)
  has no NVFP4 type; only `MXFP4_MOE` exists. The chosen local tier is therefore
  `…-lightning-30b-a3b-gguf-mxfp4_moe`.

**The driver order is a separate order from `local-router/fallback-models`.** The shared 20-step
chain serves VS Code, Claude Code, Cline and scripts; the driver order (tier 1–4) is `ainish-rag`'s
own, carried as explicit model ids. Neither replaces the other, and reordering the shared chain for
one tool would change routing for every consumer.

**4b. Elephant.** Session-aware synthesizer.
- Input: current task text, the session's accumulated injection state (a small JSON sidecar in
  `.agents/rag/sessions/{id}.json`), retrieved context, wiki ledger.
- Output: a bounded addition to the injection — what matters *for this session* given what has
  already been established.
- Persists its own summary back to the sidecar so the next call is cheaper (this is the "remembers
  everything" behaviour, implemented as a rolling summary rather than full history).

**4c. Goldfish.** Stateless reviewer.
- Input: **only** the immediate task + retrieved context + the Elephant draft. No session sidecar,
  no COMMS, no history. This isolation is the whole point and must be enforced in code, not by
  convention.
- Output: an unfiltered addition — gaps, contradictions, things the Elephant's accumulated view
  would smooth over.

**4d. Assembly.** Concatenate under an explicit token budget with per-section caps and labelled
provenance so the consuming agent can tell Elephant from Goldfish from raw retrieval. Degrade order
when over budget: drop retrieved tail → drop Goldfish → drop Elephant → raw snippets only.

**Exit criteria:** one call returns a labelled, token-budgeted injection; Goldfish provably receives
no session state (test asserts the absence); total latency within budget on local-router, with
measured remote fallback.
**Deliverable:** `ainish-rag context --task "<text>"`.

---

### Phase 5 — The two-command agent surface + thin `AGENTS.md`

**Why:** Everything above is worthless if the agent has to learn 22 subcommands.

- **Command 1 — build/refresh:** `ainish-rag sync [path]` → index + maintain, one verb.
- **Command 2 — get context:** `ainish-rag context --task "<text>"` → the Phase 4 injection.
- All existing subcommands stay, documented as the *internal* surface.
- `AGENTS.md` shrinks to: a pointer to `.agents/**`, the two commands with one-line contracts, and
  the "RAG output is advisory, you own the decision" rule. Move the rest into `.agents/**` where
  it already belongs.
- Add `--json` and a human mode to both commands; make failure mode explicit (if the engine is
  unavailable, say so and return the agent to plain file reading — never block the task).

**Exit criteria:** a fresh agent given only `AGENTS.md` can run both commands correctly without
reading engine internals; the contract test asserts the documented surface matches `--help`.
**Deliverable:** shrunk `AGENTS.md` + the two verbs.

---

## 4.5. Working discipline for the new chat

This plan is executed against a **single `main`** in each repo. State as of 2026-11-06:

| Repo | Branch | Worktrees | Stashes |
|---|---|---|---|
| `ainish-coder` | `main` only | 1 | 0 |
| `local-router` | `main` only | 1 | 0 |

Rules for the execution chat, so history stays linear and backtrackable:

1. **One short-lived branch per phase**, named `feat/rag-phase-N-<slug>`, cut from `main` and merged
   back with `--no-ff` so the phase boundary is visible in history. Delete it on merge.
2. **Never leave a branch unmerged at the end of a session.** If a phase is incomplete, commit to
   its branch and say so explicitly — do not leave it undiscussed.
3. **Never leave an orphaned worktree.** A worktree whose `.git` pointer targets a deleted
   `gitdir` cannot be removed by `git worktree remove`; it is invisible to `git worktree list` but
   still sits on disk, and any branch only it referenced becomes undeletable. Verify with
   `git worktree list` **and** a directory listing before declaring cleanup done.
4. **One order lives in one place.** The driver order is `ainish-rag`'s; the generic chain is
   `local-router`'s. A change to either must not silently alter the other.

Documentation and code move together: a phase that changes behaviour updates this plan and
`local-router/docs/driver-models.md` in the same branch.

---

## 5. Interfaces (target)

```
ainish-rag sync [PATH] [--apply] [--json]      # build / refresh / maintain
ainish-rag context --task "<text>" [--budget N] [--json] [--no-remote]
```

Injection envelope (JSON):

```json
{
  "format": "ainish-rag/context/v1",
  "task": "...",
  "budget": {"tokens_used": 1420, "cap": 4000},
  "sections": [
    {"source": "retrieval",  "text": "...", "reason": "chunks: 6, rerank: decision"},
    {"source": "elephant",   "text": "...", "reason": "session ack: 3 prior turns"},
    {"source": "goldfish",   "text": "...", "reason": "stateless review, 2 gaps"}
  ],
  "drivers": {"elephant": "local-router:...", "goldfish": "local-router:..."},
  "degraded": false,
  "provenance": {"commit": "...", "indexed_at": "..."}
}
```

`source`/`drivers` are mandatory: a caller must always be able to tell a live local judgment from a
remote fallback.

---

## 6. Decisions needed before Phase 4 starts

1. **Does the driver model share the decision transport config or get its own?** Sharing is simpler;
   separating lets you run cheap decisions and an expensive driver.
2. **ZenMux for decisions, driver, or both?** It is currently absent from the decision chain
   (`:2674`); adding it is a small change but should be a deliberate one.
3. **Session sidecar retention** — how long does an Elephant session live, and where is it stored so
   it never leaks into a repo commit?
4. **Is the Elephant/Goldfish split a published technique or our hypothesis?** Phase 1 answers this;
   the answer changes how loudly we describe it.

---

## 7. Verification strategy

- **Per phase:** real-corpus numbers against the Phase 0 baseline — never synthetic-only.
- **Regression:** `scripts/test-pqc-dist.sh` (62 assertions today) must stay green; add engine-level
  tests alongside.
- **Contract:** a test that asserts the documented two-command surface matches `--help`.
- **Isolation:** a test that Goldfish receives no session state.
- **Latency:** a CI-enforced ceiling per command; exceeding it fails the build, not the user.
- **Security:** keys resolved in memory only, `stdin=/dev/null` on every subprocess, redaction
  checks on any text that reaches a receipt.

---

## 8. Explicitly rejected, with reasons

- **Autonomous prompt/code self-modification** — unauditable, and makes failures unreproducible.
- **A always-on multi-agent orchestration graph** — the two-agent split is the budget; more agents
  multiply latency for unproven gain (Phase 1 is the arbiter).
- **Removing the existing subcommands** — they are the internal surface and the escape hatch.
- **Making the injection mandatory for agents** — it stays advisory; the harness owns context.

---

## 9. Suggested first task for the new chat

> Execute Phase 0 on this repo and `local-router`: extend `bench` to record Recall@k, nDCG, token
> count and latency, commit the baseline, then run Phase 1 and produce `docs/rag-evidence.md` with
> Adopt/Trial/Reject for each candidate technique. Do not start Phase 2 until Phase 1 is reviewed.

That ordering is deliberate: Phase 1 can invalidate parts of Phases 2–4, and it is far cheaper to
discover that on paper than in code.

---

## Appendix A — Verified measurements (2026-11-06)

Every number below was checked against the working tree, not recalled. Re-run `.verifyplan.sh`-style
checks before trusting them if the engine has changed.

| Claim | Verified value |
|---|---|
| `src/rag/rag.py` size | **6,861 lines** |
| Top-level subcommands | **21** (`audit bench cleanup completion decide embed-provider eval gate index monitor orient query rerank route secrets serve status statusline stop wiki`) |
| Total `add_parser` calls | **33** (21 top-level + 12 nested: 8 `audit_sub`, 4 `service_sub`) |
| Generative model calls | **0** — no `chat/completions` anywhere, in **either** engine |
| zenmux in decision transport | **absent** (`:2674-2694` covers local-router, openrouter, jev, local-model only) |
| Embedding width | 768 (`DEFAULT_EMBED_DIM`, `:29`) |
| Index mode | full scan + optional `--watch`; **no** delta/incremental path |

Anchors cited in this plan, all confirmed present at the stated lines:

`rerank` (:3209) · `rerank_via_jev` (:3219) · `rerank_local` (:3301) · `_post_decisions` (:2974) ·
`derive_retrieval_strategy` (:2698) · `evaluate_context_sufficiency` (:2739) ·
`extract_corrective_expansion_terms` (:2762) · `generate_wiki` (:2232) ·
`append_wiki_note_and_sign` (:2136) · `transport_priority_order` (:2674) · `LanceStore` (:1804) ·
`index` parser (:5278) · `bench` parser (:5349)

### Appendix A.1 — Phase 0 baseline, measured 2026-11-06

Recorded by `ainish-rag bench --save-baseline` against this repo's full store (3,627 records) at
commit `fab34e1`. Committed at `.agents/rag/bench-baseline.json` (`format:
ainish-rag/bench-baseline/v2`). Reproduce with:

    ainish-rag bench --regression

| Metric | Value |
|---|---|
| Recall@3 | 1.000 (3/3) |
| nDCG@3 | 1.000 |
| Chunk tokens, avg per query | 920 |
| Avg latency | 1,149 ms |
| Store records | 3,627 |
| Embedding identity | `api:openrouter:openai/text-embedding-3-small` |

Two caveats that decide how these numbers may be used:

- **Three queries is a smoke test, not a corpus.** Recall and nDCG are both saturated, exactly as
  before; the harness can now *detect* a regression but cannot yet *discriminate* between
  techniques. Phase 2 needs a larger fixed query set before it can claim an improvement, so
  expanding the set is a prerequisite of the Phase 2 exit criteria, not a nicety.
- **The identity is the API embedding provider, not EmbeddingGemma-2.** The row above contradicts
  the "LanceDB + EmbeddingGemma-2 GGUF" claim in this document's own capability table, because the
  store on this machine was built through OpenRouter. Whichever backend is canonical, the plan and
  the code must name it consistently before cross-machine numbers mean anything.

## Appendix B — What Elephant/Goldfish is, precisely

Today `bin/egm-check.sh` is a **heading linter**: it asserts a design document contains eleven
required section titles and returns `READY_FOR_GOLDFISH`. It does not run an agent, call a model, or
produce context. The `context-orchestration` skill describes a *human/agent procedure* for applying
the pattern, not an implemented pipeline.

So the request's "elephant and goldfish agents operate ... to concatenate their context-injection
additions" is genuinely new code (Phase 4), and it depends on a generative transport that does not
exist (Phase 4a). Any estimate that assumes otherwise will be wrong.

