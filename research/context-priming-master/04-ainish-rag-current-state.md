# 04 — `ainish-rag --context` as it exists today

Anchors verified against `src/rag/rag.py` (7,854 lines) at commit `c34a328`. Every line number below
was read, not recalled.

## 1. Entry points

```
bin/ainish-rag
  └─ src/rag/rag.py  main()
       ├─ normalize_argv()            :6671  rewrites a leading `--context` to the `context` subcommand
       ├─ argparse subparsers         :6746+
       ├─ args.subcommand == "context" :6956  → run_context_command(...)
       └─ run_context_command()       :4945
```

`normalize_argv` only rewrites `--context` at index 0, so `--context` used as a value is untouched.
The alias exists because `AGENTS.md` and muscle memory both reach for the flag form.

## 2. The four sections, in evaluation order

`run_context_command` (line 4945) is the whole pipeline. Docstring:

```
orientation  code only   where am I: branch, worktree, tree state, COMMS, task, plan
retrieval    code only   the newest wiki-vault pages and .agents artifacts — the corpus
elephant     model #1    session-aware reading: what this session already settled
goldfish     models #2-4 fresh reader: comprehend, attack, then a go/no-go verdict
```

### Budget arithmetic — this is the central hard constraint

```python
CONTEXT_BUDGET_DEFAULT = 4000
CONTEXT_BUDGET_FLOOR = 300
CONTEXT_SECTION_CAPS = {"orientation": 0.12, "retrieval": 0.54, "elephant": 0.20, "goldfish": 0.14}
```

The budget is **route-derived by default** (`DecisionEngine.route(task)` → `context_budget_tokens`),
or taken verbatim from `--budget` with a floor. The comment records the invariant:

> "An explicit `--budget` is honoured exactly; only the route-derived default carries a floor. A caller
> that asks for 400 tokens and silently receives 600 cannot reason about its own context window."

**Total output for a typical call is ~3,200 tokens.** Everything this proposal adds must fit inside
that, or reduce something else to pay for itself. This is the single most important number in the
document and it should be treated the way `always_on_max` is treated in harness2: one cap, one
meaning, one place.

### `assemble_injection` — the degradation ladder

```python
def assemble_injection(task, sections, budget, provenance, degraded, degrade_notes):
    """Fits labelled sections into the budget with an explicit, ordered degradation ladder."""
```

The order is fixed and argued in comments:

1. Trim the retrieval tail (the only section with interchangeable units).
2. Drop `goldfish`.
3. Drop `elephant`.
4. Drop `orientation` **last** — "the cheapest section (no model call) and the only one that is still
   useful when everything else failed".
5. Hard-truncate retrieval if a single chunk still exceeds the cap.

Every step appends to `degrade_notes`, and `degraded` is set if any ran. **Nothing degrades silently.**

### Orientation

`render_orientation_section(repo_root, token_cap)` at :4754. Pure code, no model call: branch,
worktree, dirty paths, today's COMMS last entry, newest task record with status and scope, newest plan
with todo counts. Capped at `0.12 × budget` (`max(120, …)`).

Its cap share is the *cheapest* to compress — it is deterministic. But note the prior task record in
this dossier's own context call: orientation **advertised a finished task as active** because the task
record and plan still said `implementing` while the COMMS ledger said done. Orientation renders what
the files say; it does not reconcile them.

### Retrieval

`retrieve_context()` at :3894:

```python
strategy = route_decision["retrieval_strategy"]
if strategy == "skip_retrieval":  return {hits: [], mode: "skipped_by_route", ...}
graph = graph_retrieve(repo_root, task, want=max(6, want))
if graph["hits"]: return {... mode: graph["mode"], sufficiency: evaluate_context_sufficiency(hits)}
return {"hits": [], "mode": "wiki_graph_empty", "sufficiency": "insufficient",
        "notice": "no wiki/.agents artifact covers this task; read the files directly."}
```

`graph_retrieve()` at :3828 is the ranking:

- Terms: `_graph_terms(task)`. If empty → `wiki_graph_no_terms`.
- Weighting: IDF-style, `sum(log(1 + total/df(t)))` — "Rare terms carry the signal: a term present in
  every node separates nothing."
- Recency: `score × (0.55 + 0.45 × recency)`, where recency is a rank-based decay over nodes sorted by
  mtime.
- One hop: `bonus = score[src] × GRAPH_HOP_BONUS` (0.35).

`build_wiki_graph()` at :3695 builds the corpus. Sources come from `_graph_sources()` at :3668:

```python
GRAPH_MAX_WIKI_PAGES = 8      # newest 8 wiki pages
GRAPH_MAX_ARTIFACTS = 2       # newest 2 files per coordination folder
GRAPH_ARTIFACT_DIRS = ("comms", "memories", "plans", "suggestions", "tasks")
```

plus `.agents/llms.txt` as `kind: "map"`.

Node granularity: wiki pages are split at `## ` headings into **section** nodes
(`GRAPH_CHAPTER_CHARS = 1400` chars each), because "a hit should be a section, not a 400-line page".
Navigation headings (`related`, `backlinks`, `see also`, `links`) are boundaries but **not** nodes,
"would become its own node and compete with real sections".

Edges: explicit links first (`WIKILINK_RE` for `[[...]]`, `MDLINK_RE` for `(path.md)` — both, because
flipping the page format without teaching the extractor the bracket syntax "would have silently
dropped every explicit edge"), matched by page stem as well as path; then shared-vocabulary edges at
≥3 shared terms.

Cached at `.agents/rag/wiki-graph.json`, rebuilt when a source changes.

**This is the highest-leverage learnable surface in the system.** `GRAPH_MAX_WIKI_PAGES`,
`GRAPH_MAX_ARTIFACTS`, `GRAPH_CHAPTER_CHARS`, `GRAPH_HOP_BONUS`, the 0.55/0.45 recency split, the ≥3
shared-term threshold, and `_graph_terms`' stopword behaviour are all **module-level constants with
hand-tuned values and no per-repo calibration**. Every one of them is a number a per-repo learning
loop could plausibly tune, and every one of them is currently a guess that happens to work on *this*
repository.

### Elephant

`elephant_synthesize()` at :4469. Signature enforces its inputs: `(driver, task, session,
retrieval_text, token_cap, hits, repo_root)`. It attaches full files from hits
(`_attach_paths_from_hits`) and passes a `retrieval_text[:6000]` inline excerpt — evidence served as
files plus a pointer, exactly the harness2 pattern, already implemented.

Session state: `.agents/rag/sessions/{branch}.json`, `SESSION_FORMAT =
"ainish-rag/elephant-session/v1"`, `SESSION_SUMMARY_LIMIT = 1600`, `SESSION_MAX_TURNS = 40`.
`save_elephant_session` rolls the summary forward and appends the task to `established`, capped at the
last 12 items. Both fields are `scrub_sensitive_content`-ed and `sanitize_note_input`-ed on the way in
and out.

### Goldfish

`goldfish_review()` — three steps, separate briefs:
`goldfish_comprehension_brief()`, `goldfish_antagonistic_brief()`,
`goldfish_readiness_brief()`. Signature: `(driver, task, retrieval_text, elephant_text, token_cap,
hits, repo_root)` — it **cannot** see the goldfish draft's provenance, only the text.

Reviewer independence is a precondition, not a report:

```python
reviewer_separation = "distinct-model"
if _same_model(eleph_model, fish_model):
    reviewer_separation = "fresh-context"
    separation_reason = ("same model (...) in a separate --no-session context; "
                         "pin AINISH_RAG_GOLDFISH_MODEL for distinct-model independence")
```

Same-model is the default and is **not** a refusal — the contract is a fresh *context*, which
`--no-session` guarantees. What is forbidden is reporting it as independent. `--allow-self-review` /
`AINISH_RAG_ALLOW_SELF_REVIEW=1` is the recorded downgrade.

Steps are reported individually (`reviewer_steps`), and a missing third step is stated:
"_a partial review that says nothing about its missing third reads as a complete one_".

## 3. Provenance and the envelope

`assemble_injection` returns:

```python
{"format": CONTEXT_FORMAT, "task": task,
 "budget": {"tokens_used": ..., "cap": ...},
 "sections": kept, "provenance": {...}, "degraded": ..., "degrade_notes": [...]}
```

`provenance` carries `commit`, `branch`, `route`, `strategy`, `session`, `drivers`, `wiki`,
`reviewer_isolation`, `engine`. `drivers` carries `elephant`/`goldfish` source, both requested models,
`reviewer_isolation`, `reviewer_separated`, `reviewer_steps`, served models.

Rendered by `render_injection_text()` inside `<CONTEXT_INJECTION>` markers, with a header line
carrying `3194/3600 tokens`, commit, and `degraded:`. A `<!-- pair: ... -->` comment names both role
models and whether they were distinct.

**There is no field anywhere in this envelope for "what this repo has learned".** That is the gap the
whole proposal fills, and adding it must not disturb the existing shape — an agent parsing the
envelope today must keep working.

## 4. What is already good, and should not be rebuilt

Being honest about this prevents a rewrite that loses working behaviour:

| Already present | Where | Why it already matches the research |
|---|---|---|
| Code-only mechanical orientation | :4754 | Cheap, always available, correct even when both drivers fail |
| Ordered, explicit degradation ladder | :4700 | Never silently over budget; every drop is reported |
| Evidence-as-files + pointer | :4469 `_attach_paths_from_hits` | The harness2 `context/` pattern, already in use |
| Reviewer independence as precondition | :5150 | EGM's actual requirement, stated as a fact not a claim |
| Session continuity with scrubbing | :3523–:3580 | Durable cross-call memory without persisting secrets |
| Degradation is always reported | throughout | `degraded` + `degrade_notes`, never a silent pass |
| Graph retrieval with no embedding dependency | :3828 | Works on any host — a hard requirement from this repo |

## 5. What is missing

1. **No learnable state.** Every ranking constant is a module-level literal. There is no per-repo
   parameter store, no history of what worked, and no way for the tool to be better on repo B than it
   was on repo A because of experience rather than because B happens to resemble this repo.
2. **No contrast.** Nothing in the pipeline ever runs two variants and compares them. Changes to
   retrieval are validated by `scripts/test-pqc-dist.sh` assertions on *shape* and by a human reading
   output — never by measuring whether the assembled prime was actually useful.
3. **No outcome signal at all.** A `--context` call leaves no record of whether the agent then found
   what it needed. The only trace is `elephant_session.turns`.
4. **No self-assessment of the prime.** `evaluate_context_sufficiency()` scores *retrieval hits*, not
   the prime. There is no "was this injection good enough to act on" signal independent of Goldfish's
   verdict on the *task*.
5. **Nothing per-repo.** `ainish-coder --rules` deploys identical files to every target. The wiki is
   per-repo and generated; the graph is per-repo and cached; but no *behaviour* is per-repo.
6. **No seeding at init.** `deploy_rules_bundle` (bin/ainish-coder:231) scaffolds directories and
   copies templates. It never asks the new repo anything, so nothing about that repo can shape its
   prime until agents have already worked in it for a while.

## 6. Constraints any design must respect

| Constraint | Source | Consequence |
|---|---|---|
| `AGENTS.md` ≤ 160 lines, currently at cap | `scripts/test-pqc-dist.sh:722,878` | Do not add contract prose. This work needs none. |
| `rag.py` is stdlib-only | imports at :10–28 | No numpy, no scheduler, no third-party store |
| `.agents/rag/` is gitignored except `bench-baseline.json` | `.gitignore:175,178` | Learned state there does not survive a clone — the operator must choose commitment |
| Budget ~4000 tokens default, sections fixed at 12/54/20/14 % | :3484–:3491 | A new section must take its share from an existing one |
| `ORIENT_PRIMER` is wiki-generated | `generate_wiki` :1183, vault guard | Hand-written guidance there would be overwritten |
| `--context` must never block the task | :4945 docstring | Any learning step is best-effort and off the critical path |
| Everything degrades and reports | `assemble_injection` | A missing learned state must be a stated absence, not an empty section |
