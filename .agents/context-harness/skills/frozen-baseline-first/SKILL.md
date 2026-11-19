---
title: Frozen baseline before any learning
aliases: ["generation zero", "reference execution", "baseline first"]
tags: [ainish/wiki/skill, ainish/learned, ainish/skill/improvement]
trigger: [baseline, generation zero, reference, improve, tune, calibrate, first run]
source: "https://arxiv.org/html/2610.14224v1 Figure 7"
evidence: "research/context-priming-master/sources/arxiv-2610.14224v1.md §4; 08-phase0-findings.md"
confidence: high
---

# Frozen baseline before any learning

**Refining a system without a reference is a measurable regression.** Harness² §4 Figure 7: improving the
execution harness directly, with no reference executions and no experience library, *dropped* performance —
Code 73.4 → 63.2, Web 69.9 → 65.0.

A loop that starts by editing has no way to know whether it helped. It will still report progress, because
it has nothing to compare against.

## The rule

Before the first learning step, write down a **frozen** baseline and never let the learner modify it:

```
generation 0  =  the shipped defaults, measured against THIS repository
```

- Record what the corpus actually looks like when you freeze it: how many nodes, which folders exist, how
  many hits a typical query returns.
- Every later generation is compared against generation 0, not against the previous generation. Comparing
  to the previous step measures a random walk; comparing to the baseline measures net drift from a known
  point.
- Make it **idempotent**: running setup twice must not overwrite a baseline a repo has been learning
  against.

## Why it must be frozen rather than recomputed

A baseline recomputed from current state silently follows whatever drift it was supposed to detect. If
"normal" is redefined every time you measure it, you can never observe a regression.

## The related discipline

Keep the history of every accepted generation as immutable files, so rollback is a file copy and not an
"undo" operation that can itself be wrong.
