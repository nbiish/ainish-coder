2026-11-18-14-single-command-context
---
plan_format: ainish/plan/v1
slug: single-command-context
date: 2026-11-18
status: done
branch: feat/single-command-context
worktree: /Users/nbiish/code/single-command-context
task_record: .agents/tasks/2026-11-18-14-single-command-context.md
operator: direct-instruction
---

# Plan: one command that reads the rules and keeps improving

## 1. Problem

The context system required two commands to work: `--context` to prime, and `--context-learn` to
improve. Worse, `AGENTS.md` was not in the retrieval corpus at all, so the prime an agent received could
report the branch and the last COMMS line but never the rules governing the session. The operator asked
for a single command that reads our rules, returns them to the agent, and keeps the system improving.

## 2. Anchor Facts

- `AGENTS.md` was absent from the retrieval graph — `_graph_sources` enumerated only the wiki vault and
  `.agents/{comms,memories,plans,suggestions,tasks}`; `any('AGENTS' in n.path ...)` returned `False`.
- The node loop stamped `"kind": "wiki"` on every heading-split source, so a contract node could not be
  distinguished from a wiki page.
- `DecisionEngine.route` can return `skip_retrieval`, in which case the prime contained zero mention of
  the contract — observed on a trivial probe task.
- `AGENTS.md` sits at a hard 160-line gate (`scripts/test-pqc-dist.sh:722`, `:878`), so any addition must
  be paid