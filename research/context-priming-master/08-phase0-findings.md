# 08 — Phase 0 findings: the gate as designed is circular. Do not build the loop.

Date: 2026-11-17. Scripts: [`phase0.py`](phase0.py), [`phase0b_monotonicity.py`](phase0b_monotonicity.py).
Both are throwaway experiments on real output from `src/rag/rag.py`, not reimplementations.

## The short version

Phase 0 asked whether five mechanical signals can distinguish a good prime from a bad one, because
the proposed acceptance gate is built on them. **They cannot.** Four of the five are restatements of
the knob that produced them, one is degenerate, and the probe set is confounded by self-retrieval.

**A learning loop whose acceptance gate is `coverage` plus `cost` will approve every widening of the
retrieval window and reject every narrowing, forever, regardless of whether the prime became more
useful.** That is worse than no learning loop: it is a monotonic drift with a progress report.

Per the plan's §7, this returns the plan to `status: designing`. Phases 1–5 as written should not
proceed.

---

## What was run

**`phase0.py`** — 8 real probe tasks drawn from `.agents/tasks/*.md` (`- objective:`) and
`.agents/plans/*.md` (`## 1. Problem`), newest first. Each rendered through production
`graph_retrieve` under three profiles, with the module constants monkeypatched so the scoring loop
itself was unmodified code:

| Profile | max_wiki_pages | max_artifacts | chapter_chars | hop_bonus |
|---|---|---|---|---|
| base | 8 | 2 | 1400 | 0.35 |
| wide | 16 | 6 | 2400 | 0.60 |
| narrow | 3 | 1 | 600 | 0.15 |

### First result — the naive statistic

Comparing means across profiles initially said only **2 of 5** discriminate (concentration, cost).
That analysis was wrong, and I recorded it before correcting it: comparing means conflates task
difficulty with profile quality. A hard task covers less under *every* profile.

### Second result — the correct statistic

A harness² contrast is **paired**: the same task under two harnesses. Paired win rates over the 8
tasks:

| Signal | wide wins | narrow wins | ties | win rate | verdict |
|---|---|---|---|---|---|
| coverage | 7 | 0 | 1 | 1.000 | discriminates |
| concentration | 8 | 0 | 0 | 1.000 | discriminates |
| freshness | 2 | 0 | 6 | 1.000 | **degenerate** |
| redundancy | 5 | 3 | 0 | 0.625 | noisy |
| cost | 0 | 8 | 0 | 0.000 | discriminates |

4/5 "discriminate". **This is the result that would have shipped a broken feature**, so it was worth
interrogating rather than celebrating.

---

## Why it is meaningless

### 1. The signals are the knobs (the fatal finding)

`wide` sets **four** knobs larger at once and `narrow` sets the same four smaller. A wider window
mechanically yields more text, so of course it covers more terms and costs more. `phase0b` sweeps one
knob at a time, holding the base profile's other values fixed, and reports Spearman ρ between the
knob's value and the mean signal across the 8 tasks:

| knob | coverage | concentration | freshness | redundancy | cost |
|---|---|---|---|---|---|
| max_wiki_pages | 0.866 | −0.224 | 0.000 | 0.894 | −0.894 |
| max_artifacts | **0.975** | 0.700 | 0.000 | **1.000** | 0.800 |
| chapter_chars | **0.975** | 0.800 | 0.000 | **−0.900** | **1.000** |
| hop_bonus | −0.447 | **0.975** | 0.000 | 0.700 | **−1.000** |

Seven pairs at |ρ| ≥ 0.9. In plain terms:

- `chapter_chars → cost` at ρ = **1.000**. Cost is not a measure of the prime; it *is* the chapter
  size. Any cap built on it enforces "never use bigger chapters" as a law of nature.
- `max_artifacts → redundancy` at ρ = **1.000**. Redundancy simply counts how many artifacts you
  fetched. It cannot detect actually-redundant content.
- `hop_bonus → concentration` at ρ = **0.975**. Concentration measures graph-walk strength.
- `max_artifacts → coverage` and `chapter_chars → coverage` both at ρ = **0.975**.

A gate "accept if coverage rises and cost does not" therefore accepts exactly one thing: *more
window*, until the bounds are hit. It would then sit at the bound and report convergence. That is the
S1 self-bloat failure with better instrumentation.

### 2. `freshness` is degenerate

Across 8 tasks there are only **two** distinct `(base, wide, narrow)` triples, and 6 of 8 are
`(1.0, 1.0, 1.0)`. It is a binary "did any recent node get retrieved", which in a repository whose
corpus is mostly recent `.agents/` artifacts is almost always yes. It cannot gate anything. Its
apparent perfect win rate is 2 wins in 2 decided cases.

### 3. The probe set is confounded by self-retrieval

The probes are drawn from `.agents/tasks/` and `.agents/plans/`, which are **themselves graph
sources** (`GRAPH_ARTIFACT_DIRS` includes both). Checking whether each probe's own file appeared
among its hits:

| probe | base | wide | narrow |
|---|---|---|---|
| 2026-11-17-13-federation-discoverability | SELF | SELF | SELF |
| 2026-11-15-09-watch-suggestions | SELF | SELF | — |
| 2026-11-14-23-machine-watch-daemon | — | SELF | — |
| 2026-11-14-22-branch-materialization-latest | — | SELF | — |
| 2026-11-14-21-machine-link-federation | — | SELF | — |
| 2026-11-10-windows-main-sync-task | — | — | — |
| 2026-11-10-machine-sync-task | — | — | — |
| 2026-11-08-plans-artifact-task | — | — | — |

`wide` retrieves the probe's own source file in 3 tasks where `base` does not, and `narrow` in 2 where
`base` does not. So part of `coverage`'s 7/8 win rate is **the experiment measuring its own probe**,
not the prime getting better. Any task-text-derived probe set has this defect in this repository,
because task records are corpus.

### 4. The circularity is structural, not fixable by tuning

It would be tempting to conclude "the signals need sharpening". They do not; the problem is deeper.
These five signals are **properties of the retrieval window**, and the learnable parameters **are the
retrieval window**. Measuring a harness by a statistic computed from the same harness's output, with
no external referent, cannot distinguish improvement from drift — which is exactly what Harness² says
about its own contrasts ("these contrasts inform subsequent composition rather than verify task
correctness") and what its Figure 7 result demonstrates when the reference is removed.

Harness² escapes this because it has a **real execution**: a trajectory and a deliverable, and a
*candidate harness that was actually run on the task*. It compares two runs, not two renderings. We
have no equivalent. Rendering a prime twice and comparing token statistics is not a probe.

---

## What this rule out, and what it does not

**Ruled out:** the learning loop in [`05-design.md`](05-design.md) §5 and
[`05b-design-widened-surface.md`](05b-design-widened-surface.md) §3, which rests on these signals.
Phase 3 of the implementation plan should not be built.

**Not ruled out — and probably still worth building:**

| Component | Status after Phase 0 |
|---|---|
| `PrimeProfile` as a **declared** per-repo configuration (Phase 1) | **Sound.** Bounded, validated, tracked, reported in provenance. Useful without any learning: a repo can state its corpus shape deliberately. |
| Generation 0 at `--rules` (Phase 2) | **Sound**, and more useful now — it is a calibration record, not a baseline for contrast. |
| Status / rollback / expiry (Phase 4) | **Sound.** Configuration surfaces need history regardless of who writes them. |
| Staging + promotion for learned skills (design §4.2) | **Sound and unchanged.** Your call to stage stands; it is orthogonal to how the edits are produced. |
| `_skill_learned` in the deploy sweep (R13) | **Still a real bug.** Even a *declared* skill pack named `learned-*` would be swept. |
| The learning loop itself (Phase 3) | **Blocked pending a real outcome signal.** |
| Skill files authored by an improver | **Blocked with it** — they were gated by the same acceptance rule. |

## What a real outcome signal would have to look like

Not a statistic computed from the prime. Something that observes the *agent* after the prime, e.g.:

1. **Did the agent read files directly anyway?** If `--context` was followed by the agent opening the
   same files by hand, the prime failed to orient it. Measurable from transcripts.
2. **Did the task end `done` or `blocked`?** `.agents/tasks/*.md` already carries `status`. Weakly
   causal and heavily confounded, but real.
3. **Goldfish readiness verdict over a task stream.** `ready` vs `not-ready` is already computed on
   every call (`goldfish_readiness_brief`, step 3 of 3). A profile that raises the `ready` rate across
   comparable tasks is measurably better — this is the most promising candidate because it is already
   being computed and costs nothing extra.
4. **A labelled probe set.** The honest one, and the one this environment does not have.

Option 3 is worth one experiment before abandoning the loop: it is the only existing signal that is
*about the prime* rather than *about the window*. But it is confounded by goldfish's own variance, and
each sample costs three model calls, so a paired test needs budget the operator should approve first.

## The finding that outlives this plan

**A self-improving system whose only measurement is derived from its own output will optimise the
measurement.** Both research sources warned about this from different directions — Harness² by making
the reference execution mandatory, the practitioner video by having its agent copy the hidden check
names out of the task description. The cheap answer to "should we build the loop" turned out to be
"not like this", and it cost an afternoon rather than 800 lines.
