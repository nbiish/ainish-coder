---
title: Cheap form first, expensive form last
aliases: ["cheap form", "always-on last", "component choice"]
tags: [ainish/wiki/skill, ainish/learned, ainish/skill/composition]
trigger: [harness, component, always-on, skill, script, subagent, plugin, prompt]
source: "https://arxiv.org/html/2610.14224v1 §2.2 + google-research/harness2 prompts.py"
evidence: "research/context-priming-master/02-harness2-mechanics.md; sources/arxiv-2610.14224v1.md (the 8-component table)"
confidence: high
---

# Cheap form first, expensive form last

When adding a capability to an agent's harness, the expensive form is the obvious one and it is almost
always wrong. Always-on prose is paid on **every** run and competes with the agent's own output budget.

Choose in this order, and stop at the first form that works:

| Order | Form | Cost when unused |
|---|---|---|
| 1 | **skill** (on-demand procedure with a recognizable trigger) | zero |
| 2 | **script** (deterministic, run via shell) | zero |
| 3 | **subagent** (bounded investigation: big input, small answer) | zero |
| 4 | **hook / plugin** (acts inside the tool loop, cannot be skipped) | zero |
| 5 | **always-on text** (a short rule that genuinely applies to every run) | every run |

## The rule

If you are about to add a paragraph to the system prompt, ask first whether it has a recognizable
trigger. If it does, it is a skill. If it is a deterministic operation the agent keeps hand-rolling and
getting wrong, it is a script. Only a rule that applies on **every single run** earns always-on budget —
and then you must cut something else to pay for it.

## Why this is not a style preference

Always-on text makes the "reasons until the budget is gone and produces nothing" failure *more* likely,
not less. The 2026-11-17 practitioner run measured this directly: a harness that kept adding checks to
its own `before_done` hook consumed 100% of the time its cached parser had saved, by task 5.

## The inverse trap

A skill nobody invokes is dead weight. If you add one, its trigger must be named in the always-on
surface in the **same** edit, or the next agent will never know it exists.
