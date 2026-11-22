---
title: Contrast, not score, when there is no ground truth
aliases: ["propose probe compose", "labelled-free improvement", "behavioural contrast"]
tags: [ainish/wiki/skill, ainish/learned, ainish/skill/improvement]
trigger: [improve, compare, contrast, evaluate, verifier, no labels, probe, baseline]
source: "https://arxiv.org/html/2610.14224v1 §2.2.1"
evidence: "research/context-priming-master/02-harness2-mechanics.md (recursion.py, selection.py); sources/arxiv-2610.14224v1.md §2.2"
confidence: high
---

# Contrast, not score, when there is no ground truth

Most repositories have no labels for "was this context call good". The instinct is to invent a score and
optimise it. That instinct is the bug.

## What to do instead

Run **two** variants of the thing on **the same** input, and compare their behaviour. Harness² calls this
Propose–Probe–Compose:

1. **Propose** two candidates from a reference run — one targeting *how the agent works* (planning, tool
   use, context management, delegation) and one targeting *what this domain knows*.
2. **Probe** each on the same task under the same model and environment.
3. **Compose** selectively: merge supported changes, revise conflicts, adopt one, or **keep the base**.

Every decision ties to a **concrete observation**, never to a presumed score gain.

## Why the score is the bug

A statistic computed from the same output you are trying to improve is **circular**. Measured on this
repository (`08-phase0-findings.md`): of five plausible acceptance signals, seven knob→signal pairs were
monotone at Spearman ρ ≥ 0.9, one at ρ = 1.000 — the "cost" signal *was* the chapter-size knob. A gate
built on them would have approved every widening of the retrieval window forever and reported it as
progress.

## The part everyone skips

Composition is **selective**, and keeping the base is a first-class outcome. In the practitioner run, an
elaborate recursive harness *matched* a frozen three-tool harness exactly on round 1 — so "no change" is
often the correct answer, and a loop that cannot report it will manufacture false progress.

## When you do have an external referent, use it

A commit that landed, a test that passed, a verdict from a reviewer that is not the drafter. Prefer one
weak external signal over a strong internal one.
