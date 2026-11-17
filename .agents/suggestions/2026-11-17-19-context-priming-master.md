---
date: 2026-11-17
topic: context-priming master system (Harness² + practitioner evidence)
status: research complete, implementation not started
---

# Finding: `--context` has no learnable state, and the research says how to add it safely

Research dossier: [`research/context-priming-master/`](../../research/context-priming-master/README.md)
(read `README.md` first, then `05-design.md`, `05b-design-widened-surface.md` and
`07-implementation-plan.md`).

## The gap, measured

`src/rag/rag.py` has **no per-repo learning path**. Every retrieval constant is a module-level
literal chosen by hand for this repository:

- `GRAPH_MAX_WIKI_PAGES = 8`, `GRAPH_MAX_ARTIFACTS = 2`, `GRAPH_CHAPTER_CHARS = 1400`,
  `GRAPH_HOP_BONUS = 0.35` (`rag.py:3591–3594`)
- the `0.55 + 0.45 × recency` weighting (`rag.py:3857`)
- the `len(shared) >= 3` shared-vocabulary edge threshold (`rag.py:3787`)
- `CONTEXT_SECTION_CAPS` 12/54/20/14 % (`rag.py:3489`)

Nothing in the pipeline ever runs two variants and compares them, and no `--context` call records
whether the prime was useful. `evaluate_context_sufficiency()` scores retrieval *hits*, not the
injection.

## What the research actually supports

Harness² (arXiv 2610.14224, `google-research/harness2`) gives a two-level recursion that needs no
ground-truth verifier — refine a harness for the current task by contrastive Propose–Probe–Compose,
then learn *how to refine* into a persistent evidence-backed library. Two of its findings constrain us
hard:

1. **Refining a harness without a reference execution and a library is a regression** (Code 73.4 →
   63.2, Web 69.9 → 65.0). A generation-0 baseline is therefore mandatory, not a nicety.
2. **Ablations**: library −3.1/−1.8, scoped editors −2.9/−3.7, composition −1.6/−1.9. All three earn
   their place.

The practitioner video supplies the failure modes the paper does not: **self-bloat** (a growing
`before_done` checklist consumed 100% of the savings by task 5), **re-verification loops**, and
**criterion leakage** (the agent copied hidden check names out of the task description). Its round 1
result is the humbling one: an elegant recursive harness **matched** a frozen three-tool harness
exactly. Recursion pays only when a capability is expensive to rebuild, tasks repeat in a domain
family, and the evolved harness stays lean.

## The proposed shape (not implemented)

A `PrimeProfile` — bounded scalars and short token lists only, no prose, no code — at
`.agents/context-harness/prime-profile.json` (tracked, unlike `.agents/rag/`). Learning is a separate
opt-in verb `--context-learn`; `--context` only reads the profile. Generation 0 is frozen and written
idempotently by `ainish-coder --rules`. Acceptance is a deterministic gate over five mechanical
signals (coverage, concentration, freshness, redundancy, cost), with `KEEP_BASE` as a first-class
outcome — which, given round 1, may be the most common one.

## Why this note exists

The federation task (`2026-11-17-13`) established that an unadvertised capability is dead capability.
This note is the discoverability surface for the research until implementation starts; the dossier is
the durable artifact.

## Open question for the operator before any code

Phase 0 in the plan is a cheap throwaway experiment to test whether the five signals separate
wide/narrow/base profiles **at all** on this repository. If they do not, the loop should not be built —
and that is worth knowing before ~800 lines land. Nothing in the dossier commits us to building it.
