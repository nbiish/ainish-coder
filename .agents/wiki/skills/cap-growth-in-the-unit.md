---
title: Cap growth in the unit being grown
aliases: ["anti-bloat", "self-bloat", "growth budget", "always-on cap"]
tags: [ainish/wiki/skill, ainish/learned, ainish/skill/guardrail]
trigger: [bloat, grow, cap, budget, reflection, hook, checklist, accumulate]
source: "https://www.youtube.com/watch?v=XaJi7a0UChs (round 3) + harness2 tree.py always_on_max"
evidence: "research/context-priming-master/03-practitioner-evidence.md; sources/video1-XaJi7a0UChs-transcript.txt"
confidence: high
---

# Cap growth in the unit being grown

A self-improving system that can grow without limit will grow until it defeats its own purpose. This is
not a hypothetical: it is the measured failure mode of every recursive harness anyone has built.

## The measurement

A harness was given five tasks in one binary-format family. On task 1 it built a parser and cached it.
Every subsequent reflection added more checks to its own `before_done` hook. By task 5 the checklist took
longer to run than the parser saved — **100% of the gain, consumed by the guardrails meant to protect it.**
The same run produced a re-verification loop (re-checking a page that had already passed until time ran
out) and criterion leakage (copied hidden check names out of the task description).

## The rule

**Cap the thing that grows, in the unit in which it grows, in code.**

- If the risk is always-on text, the cap is **characters of always-on text** — one constant, one meaning,
  checked in one place. Harness² does exactly this with `always_on_max`.
- Not "a maximum number of files" (unrelated to cost), not "a token estimate" (a second budget that drifts
  from the first), and never a sentence in a prompt asking the model to be brief.
- Store the *reason* beside the cap so the refusal explains itself without a second lookup table.

## Cap the derivative too

Growth rate matters as much as size. A system that may double every generation is unbounded even with a
ceiling. This repo caps `domain_prior` hints at 12 per domain and expires any hint unsupported for N
generations, so the profile cannot become a sediment of everything ever tried.

## Reflection is the growth vector

Any "reflect and improve" step is where accumulation happens. Keep reflections short, and **strictly cap
whatever they are allowed to append to**. An uncapped hook is an unbounded loop with a progress report.
