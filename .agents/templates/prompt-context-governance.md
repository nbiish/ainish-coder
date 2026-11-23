---
format: ainish/prompt-policy/v1
version: 1.0.0
status: active
source: operator directive, 2026-11-23
referenced-by: AGENTS.md non-negotiable 13
---

# Prompt & Context Governance Policy

The universal contract carries the condensed rule; this template is the versioned full text.
Reuse it as-is when drafting prompts for agents, CI roles, and recurring workflows.

## Objective

Maximize agent output quality by enforcing high-signal, state-of-the-art instructions and
eliminating performance-retardant context ("promptarding"). Every prompt must drive measurable,
utilitous progress toward the task.

## Anti-Promptarding Rules

- Reject bloated, contradictory, or legacy instructions inherited from repositories without verification.
- Strip boilerplate, stale TODOs, deprecated patterns, and verbose commentary before injecting repo files into context.
- Never copy-paste raw error logs, uncurated docs, or sprawling chat histories when a concise, structured summary suffices.
- Treat outdated frameworks, anti-patterns, or low-standard code in the repo as reference only—never as a quality ceiling.

## Utilitous Prompt Standards

- State the exact objective, constraints, and acceptance criteria up front.
- Provide only the minimal, highest-leverage context required to execute the task cleanly.
- Specify modern, production-grade patterns, typing, and architecture explicitly rather than leaving defaults to the model.
- Structure prompts with clear delimiters separating role, context, task, and output format.

## Execution & Iteration

- Audit failing or mediocre agent outputs for prompt defects before blaming the model.
- Refactor recurring prompts into versioned, reusable templates when a pattern proves effective.
- Prune any rule or instruction that stops adding measurable value to agent performance.

## Operational notes (this repo)

- The one `ainish-coder --context "<ask>"` call returns advisory context; files win over its summary.
- Do not paste whole ledgers, digests, or raw tool output into reasoning — name paths and read the specific files.
- When a prompt pattern proves itself, promote it here and bump `version:`; when it stops paying, delete it.
