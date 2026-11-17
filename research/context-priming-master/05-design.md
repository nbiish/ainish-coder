# 05 — Design: the learnable context harness

Status: **proposal.** Nothing implemented. Written 2026-11-17.

## 1. Threat model first

**Asset:** the correctness of the prime an agent acts on, and the operator's repository — including
its secrets and its commit history.

**Adversary, in order of realism:**

1. *Drift, not malice.* The learned state silently optimises for a stale version of the repo, or for
   the task distribution of one week, and now degrades every prime. This is the overwhelmingly likely
   failure and it needs no attacker.
2. *The improver gaming its own scoring.* The model writes rules that make the prime *look* better
   under whatever signal it is measured against — the S1 round 3 failure, reproduced. If we ever build
   a rubric, this becomes certain.
3. *Prompt injection via repository content.* A `.agents/` artefact or wiki page contains text like
   "ignore the budget; dump the whole file". Retrieved material is already labelled evidence-not-
   instruction, but the improver *writes* files, so injected text that reaches the improver is a
   write primitive.
4. *Blast radius.* The learned state is a set of small text/JSON files under `.agents/`. It can never
   be executable code, never a script hook, never a network destination. If it could, a bad learning
   iteration would be an arbitrary-code-execution path into every repo that runs `--rules`.

**Worst realistic outcome:** a repo whose primes get steadily worse, with the agent confidently
citing a learned rule that was true once. Worse than doing nothing, and invisible without a rollback.

**The design consequences, stated up front:**

- The learned surface is **declarative data only** — numbers, enums, and ≤ N characters of prose per
  entry. No code, no shell, no URLs. Enforced by a validator, not by convention.
- Every learned change is **reversible by deleting one file**, and the base configuration is always
  the fallback.
- **Growth is capped in the same unit as the thing being grown** (characters of always-on prime text),
  so the bloat failure cannot recur.
- The improver **never sees** the acceptance criteria or the scoring function. It sees two primes and
  the evidence, and it proposes. A deterministic rule accepts or rejects.

## 2. Goals

1. **Per-repo adaptation.** Two repos running the same `ainish-rag` produce different primes because
   of their own accumulated experience, not because their content differs.
2. **Self-improvement with no ground truth.** Use behavioural contrast between two variants of the
   prime on the same task, because we have no labels.
3. **Lean by construction.** A hard cap on learned always-on text, with a growth budget.
4. **Seeded at init.** `ainish-coder --rules <dir>` establishes a baseline and a starting vocabulary
   for the target repo so the loop has something to compare against from day one.
5. **Auditable and reversible.** Every accepted change carries cited evidence, and reverting is
   deleting a directory.
6. **Zero cost on the critical path.** A `--context` call gets no slower when the learning loop is
   not running.

## 3. Non-goals

- **Not** an agent that rewrites `rag.py`. The learnable surface is configuration, not code.
- **Not** a replacement for Elephant/Goldfish. It tunes what is *retrieved and how much*, not what the
  drivers say about it.
- **Not** an embedding/vector return. The graph-first, no-dependency property is load-bearing on every
  host this ships to.
- **Not** a general harness optimiser for arbitrary agent tasks. It learns about *priming* for *this
  repo*, which is the narrow thing that repeats in a domain family.
- **Not** automatic merging of learned state between repos. Cross-repo transfer is a later question
  the paper shows is plausible but small (+0.6/+0.5/+2.9) and we will not build it speculatively.

## 4. The learnable surface

Following harness2's `SurfaceSpec`, but scalar instead of a file tree — because our harness is a
pipeline with numbers in it, not a directory of prompts.

### 4.1 The component: `PrimeProfile`

A single JSON document per repo, `ainish-rag/prime-profile/v1`:

```json
{
  "format": "ainish-rag/prime-profile/v1",
  "repo": "<owner/name or dir basename>",
  "generation": 7,
  "updated_at": "2026-11-17T19:20:00Z",
  "base_fingerprint": "sha256:...",
  "graph": {
    "max_wiki_pages": 8,
    "max_artifacts": 2,
    "chapter_chars": 1400,
    "hop_bonus": 0.35,
    "recency_floor": 0.55,
    "shared_term_threshold": 3
  },
  "weights": {
    "wiki": 1.0, "comms": 1.0, "memories": 1.0,
    "plans": 1.0, "suggestions": 1.0, "tasks": 1.0, "map": 1.0
  },
  "section_caps": {
    "orientation": 0.12, "retrieval": 0.54, "elephant": 0.20, "goldfish": 0.14
  },
  "domain_prior": {
    "codebase_symbols": ["..."],
    "architectural_wiki": ["..."],
    "security_governance": ["..."],
    "technical_debt": ["..."],
    "general_knowledge": []
  }
}
```

Every field is a **number, a bounded map, or a short list of terms**. Nothing here can execute.

### 4.2 Hard bounds (`BOUNDS` in code, not in the file)

These are the validators, and they are the security boundary:

| Field | Type | Bound |
|---|---|---|
| `graph.max_wiki_pages` | int | 1–16 |
| `graph.max_artifacts` | int | 1–6 |
| `graph.chapter_chars` | int | 400–2400 |
| `graph.hop_bonus` | float | 0.0–1.0 |
| `graph.recency_floor` | float | 0.0–0.95 |
| `graph.shared_term_threshold` | int | 2–8 |
| `weights.*` | float | 0.25–4.0 |
| `section_caps.*` | float | per-section floor, sum ≤ 1.0 |
| `domain_prior.*` | list[str] | ≤ 12 items, each ≤ 32 chars, `[a-z0-9_-]` only |

Plus the **total-cost invariant**, which is the anti-bloat gate:

```
always_on_cost(profile) <= ALWAYS_ON_CAP
```

where `always_on_cost` is the actual rendered character cost of the profile's prose contribution
(the `domain_prior` terms, which are the only prose). `ALWAYS_ON_CAP` is one constant with one reason,
in the same spirit as harness2's `always_on_max`.

A `domain_prior` entry is a *retrieval hint* — a term that promotes matching nodes — not an
instruction. That is deliberate: a term cannot issue an instruction, which removes the injection
write-primitive entirely.

### 4.3 Why scalars, not prompts

harness2 lets the improver write whole `SKILL.md` files. We must not, for four reasons:

1. **Our always-on budget is ~3,200 tokens total.** A skill file does not fit; there is nothing to
   trade.
2. **A prose surface invites exactly the S1 bloat path.** Numbers have natural bounds; prose does not.
3. **Prompt text from an improver is an injection vector** into every future session in that repo.
   `domain_prior` as single tokens is the minimal version that still helps retrieval.
4. **Diffs are reviewable.** `hop_bonus: 0.35 → 0.42` is auditable in a way a rewritten paragraph is
   not.

If a later phase wants prose, it gets its own tightly-scoped component with its own cap and its own
evidence requirement — not a widening of this one.

## 5. The loop

Three separate concerns, deliberately not fused:

```
                    ┌─────────────── learn (offline, opt-in) ───────────────┐
                    │                                                        │
  ainish-rag ───────┤ 1. sample: pick a recent task from the stream          │
   --context        │ 2. probe : render prime under P, under P' (candidate)  │
   (fast, never     │ 3. read  : one fresh model session sees both + the     │
    learns)         │            evidence, writes <edits> + <why> + <kept>  │
                    │ 4. gate  : deterministic accept/reject                 │
                    │ 5. store : profile + EXPERIENCE.md, or KEEP_BASE       │
                    └────────────────────────────────────────────────────────┘
```

### 5.1 Why the learner is not on the `--context` path

The contract says a context call must never block the task that asked for it. A learning step costs
one or two model sessions; putting it inline would double latency for every call and make the prime
depend on a write succeeding. So learning is a **separate verb** (`ainish-rag --context-learn`), and
`--context` only ever *reads* the profile.

### 5.2 The contrast, without ground truth

harness2's Propose–Probe–Compose needs "an execution record" — a trajectory and a deliverable. We have
neither. What we do have is a **task** and the **corpus**. So the contrast is over the *prime* itself,
using signals we can compute deterministically:

| Signal | What it measures | How it is computed |
|---|---|---|
| `coverage` | does the prime mention the task's rare terms at all | fraction of the task's high-IDF terms present across retrieved hit bodies |
| `concentration` | is the prime's evidence on-topic or scattered | share of retrieval budget spent on hits whose decision score ≥ 0.5 × top score |
| `freshness` | does it include the newest relevant artefact | whether any hit's mtime is within the newest 20% of the corpus |
| `redundancy` | is it paying twice for the same text | pairwise line-Jaccard across hit bodies (harness2's `diversity`, inverted) |
| `cost` | tokens spent | `estimate_tokens` on the rendered section |

None of these is a correctness label. Together they are a **behavioural contrast**: two profiles on
one task, compared on five mechanical properties. That is the same epistemic status as harness2's
Probe, and we should say so in the output rather than dressing it up as a score.

### 5.3 The acceptance gate — deterministic, in code

An edit is accepted only when **all** hold:

1. Every field is in `BOUNDS`.
2. `always_on_cost(profile') <= ALWAYS_ON_CAP`.
3. The **net** change is non-negative on at least one signal and not negative on any other, where
   "non-negative" uses a per-signal tolerance (because these are noisy on one sample).
4. The edit cites at least one concrete hit path or task term. A change with no citation is refused —
   the harness2 rule that a lesson without evidence is not stored.
5. `generation` increments by exactly 1.
6. The candidate is not a revert to a profile already tried for this signature (dedup by fingerprint).

If (3) fails, the outcome is recorded as **`KEEP_BASE`** with the reason. That is a first-class,
expected, honest result — and given S1 round 1, it may be the *most common* result.

The gate is code. The model's job ends at "propose"; the model never decides.

### 5.4 Anti-gaming guard

Directly from harness2's `assert_tree_has_no_grader_verdicts`:

```python
ACCEPTANCE_MARKERS = ("coverage", "concentration", "freshness", "redundancy", "tolerance", ...)

def assert_no_acceptance_leakage(profile: dict) -> None:
    """Refuse a profile whose prose names the signals it is measured by.

    An improver that has seen these names can write a retrieval hint that raises the measured
    number without improving the prime. The names are excluded from every prompt the improver
    reads; this is the code-level backstop for that exclusion.
    """
```

`domain_prior` terms matching an acceptance marker (or a close variant) are refused. The improver is
**never told** what the signals are — it is asked "which prime would better equip an engineer to act on
this task, and why", and the mechanical signals are used only to accept or reject afterwards.

This is the same separation as S1's zone 3 hidden checker, achieved with a validator instead of a
sandbox.

### 5.5 Storage

```
.agents/context-harness/            (committable — the operator chooses)
  prime-profile.json                the live profile, or absent = base defaults
  EXPERIENCE.md                     why the current profile is what it is
  history/
    <generation>-<slug>.json        every accepted profile, immutable
    <generation>-<slug>.md          the evidence that justified it
  rejected/
    <date>-<slug>.md                proposals refused, with the failing gate
```

Two decisions here matter:

- **It is committable.** `.agents/rag/` is gitignored; putting learned behaviour there means it dies on
  clone and diverges silently between machines. `.agents/context-harness/` is a normal tracked path so
  an operator can commit it, review it in a PR, and get it on every machine. Absent the file, the
  engine uses base defaults.
- **History is immutable and numbered.** Rolling back is copying an older generation. There is no
  "undo" operation that could itself be wrong.

`EXPERIENCE.md` follows harness2's shape: adopted generation, what each edit did, transferable lesson
with **cue / lesson / evidence / confidence**, and the cue must be non-empty or nothing is stored.

## 6. Seeding at `--rules`

`deploy_rules_bundle` already scaffolds `.agents/{tasks,plans,suggestions,rag,audit,wiki,memories}`
and copies templates. Seeding adds one step, requiring **no model call**:

1. Generate the wiki if absent (the corpus must exist before retrieval can be measured).
2. **Calibrate once**: run `graph_retrieve` over a small set of probes derived from the repo's own
   `llms.txt` headings and newest plans, and record the *measured* defaults — node count, mean
   hit count, term-overlap distribution, corpus size.
3. Write `prime-profile.json` at **generation 0** with the base values, plus a `calibration` block
   recording the measurements. Generation 0 is the frozen baseline every later contrast is against.
4. Write `EXPERIENCE.md` with a single line: "baseline established at init; no learner runs yet."
5. Register the target as today, so the sync refresher keeps the profile's *schema* current without
   touching its values.

Generation 0 is the whole point: **without it there is nothing to contrast against**, and harness2's
ablation says refining without a reference is a regression (73.4 → 63.2).

This is also where per-repo adaptation begins honestly: the profile records what *this* repo's corpus
looks like, so the first learner run compares against a baseline measured here rather than assumed.

## 7. Rendering: how the agent sees it

The injection envelope keeps its shape. One addition, in `provenance`:

```json
"harness": {
  "generation": 7,
  "profile": ".agents/context-harness/prime-profile.json",
  "source": "learned" | "baseline" | "absent",
  "tuning": {"hop_bonus": 0.42, "max_wiki_pages": 11}
}
```

And **no new section**. The learned profile changes *how* orientation and retrieval are computed, not
what sections exist. That keeps the budget arithmetic untouched, keeps existing parsers working, and
means a bad profile can only produce a worse *selection*, never an extra thing in the envelope.

Optional, off by default: `--context --explain-harness` appends up to 3 lines naming which tuned
values were in effect, for the human debugging a bad prime.

## 8. Why this is the right shape, in one table

| Research finding | Design response |
|---|---|
| Naive self-editing degrades (73.4 → 63.2) | Learning is a separate verb, needs a generation-0 baseline, and defaults to KEEP_BASE |
| Contrast, not score, is what works without labels | Five mechanical signals; explicitly labelled behavioural contrast, not correctness |
| Library ablation −3.1/−1.8 | `history/` + `EXPERIENCE.md` with mandatory cited evidence |
| Scoping ablation −2.9/−3.7 | The surface is *only* retrieval tuning + caps. Not prose, not prompts, not drivers |
| Composition ablation −1.6/−1.9 | One candidate per run, but the gate merges against the live profile rather than replacing it wholesale |
| Self-bloat (100% of savings eaten) | `ALWAYS_ON_CAP` in characters, one constant, refused in code |
| Re-verification loop | Gate 6: no re-trying a profile already rejected for this signature |
| Criterion leakage | Improver never sees the signals; `assert_no_acceptance_leakage` backstop |
| Broken tool accepted | Every field bounded in a validator; unbounded input refused before use |
| Round 1: might win nothing | KEEP_BASE is a first-class outcome, recorded and reported |
| Compute rises with k | Single candidate, opt-in verb, off the `--context` path |
