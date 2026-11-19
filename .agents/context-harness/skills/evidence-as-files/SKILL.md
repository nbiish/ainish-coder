---
title: Evidence as files, prompt as pointer
aliases: ["context tree", "no truncation", "evidence on disk"]
tags: [ainish/wiki/skill, ainish/learned, ainish/skill/context]
trigger: [evidence, prompt, truncate, context window, attach, trajectory, dossier]
source: "google-research/harness2 core/context.py + spec.py obs_trunc guard"
evidence: "research/context-priming-master/02-harness2-mechanics.md §3"
confidence: high
---

# Evidence as files, prompt as pointer

> "Evidence is served as files and the prompt is a short pointer, so nothing is truncated to fit a prompt."

When a model must reason over a lot of material, the instinct is to summarise it into the prompt. That
truncation does not just lose information — it **fabricates defects**. Harness² refuses any observation cap
below 10,000 characters with the message *"is in the range that fabricates defects"*, because a model given
a clipped trajectory will diagnose a problem that exists only in the clipping, and then "fix" it.

## The shape

```
context/
  task.md              what was asked
  rollouts/<label>.md  FULL trajectories, unclipped
  evidence/<n>.md      the material, whole
  harness/             the thing being edited
  MISSION.md           what to do with all of it
```

The prompt then says only: *the evidence is on disk, read it, and cite the specific moment behind every
change.* A change you cannot trace to a moment is speculation.

## Two details that matter

1. **The layout listing must only mention paths that exist.** A listing that promises files it did not
   provide is worse than a short one — the reader concludes the evidence is missing rather than absent.
2. **Mark your own truncations.** If any individual item must be clipped, leave an explicit marker saying
   so, and tell the reader it is yours and not the subject's behaviour.

## When you cannot use files

If the reader has no file tools, inline the evidence, but keep the same discipline: clip **per item** with a
stated cap, never truncate the whole set, and never let the reader infer a defect from a boundary you drew.
