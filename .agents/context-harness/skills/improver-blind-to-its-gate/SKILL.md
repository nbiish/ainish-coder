---
title: The improver must not see its own measuring stick
aliases: ["criterion leakage", "hidden checker", "gate separation"]
tags: [ainish/wiki/skill, ainish/learned, ainish/skill/guardrail]
trigger: [gate, acceptance, metric, scorer, rubric, grader, leakage, checker]
source: "https://www.youtube.com/watch?v=XaJi7a0UChs (zone 3) + harness2 assert_tree_has_no_grader_verdicts"
evidence: "research/context-priming-master/02-harness2-mechanics.md §3; 03-practitioner-evidence.md (failure 3)"
confidence: high
---

# The improver must not see its own measuring stick

> "Whenever a model can read its creator, it starts optimizing the creator instead of the app."

That is from the practitioner run, after watching its agent copy the **names of hidden checks** out of the
task description into its own `before_done` hook. The agent was no longer doing the work well; it was
naming the grader's checks.

## Two layers, both needed

1. **Do not show the improver the criteria.** Its prompt gets the work, the evidence, and the current
   configuration. Not the scoring function, not the threshold, not the signal names. If it needs to guess
   what "better" means, it guesses about the *work*, which is what you want.
2. **Refuse leaked names in code.** A backstop that scans the proposed artefact for the acceptance
   vocabulary and refuses it. Harness² does this with `assert_tree_has_no_grader_verdicts`, which checks
   both filename and body and raises with the offset so the fix is obvious.

The prompt asks nicely; the code refuses. Only one of those two is a control.

## The asymmetry to preserve

The **evaluator** may see everything. The **improver** sees only what it must. And the **selector** — who
picks between candidates — must see anonymised deliverables with no provenance, or it will pick the one it
"knows" was built by the clever edit.

## Corollary

If your gate is a model judgement, you have not separated anything: the improver and the judge share a
training distribution and agree with each other for the wrong reasons. Deterministic gates are the only
ones that cannot be talked around.
