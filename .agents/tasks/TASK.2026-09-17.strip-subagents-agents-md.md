# Task: Strip Subagent Orchestration Content from AGENTS.md

- Date: 2026-09-17
- Branch: chore/agents-strip-subagents
- Status: closed
- Scope: AGENTS.md

## Objective
Strip out subagent orchestration content from `AGENTS.md` so agents focus on everything else in this document (worktrees, PQC secrets, OOReDAct, server lifecycle, repo-memory, triage, and quality gates). Subagent orchestration remains an on-demand skill (`.agents/skills/orchestrate-subagent-masters/SKILL.md`) for users to call as normal.

## Changes Completed
1. `AGENTS.md` Frontmatter: Removed automated subagent orchestration belief and pointer; updated coordination to ledger and tasks.
2. `AGENTS.md` `<TASK_PRIMER>`: Removed handoff references from Fast Orientation.
3. `AGENTS.md` `<COMMS>`: Focused coordination on ledger and task files; stripped subagent dispatch rules, packet hygiene/automation, and subagent lifecycle parent-attribution.
4. `AGENTS.md` `<TRIAGE>`: Retitled to `TASK TRIAGE — MULTIPLE TASKS & WORKTREES`; removed subagent fan-out and handoff packet skeleton rules.
5. `AGENTS.md` `<WORKFLOW>`: Removed subagent dispatch and handoff packet steps.
6. `AGENTS.md` `<ORCHESTRATE_SUBAGENTS>`: Replaced with `<EXECUTION>` / `## AGENT EXECUTION & OOREDACT` focusing on core OOReDAct execution and operational directives without automated subagent dispatching.
7. `AGENTS.md` `<REPO_MEMORY>`: Removed subagent dispatch rule #6.
8. `AGENTS.md` `<AUDIT>`: Removed subagent receipts from pre-commit checklist; renumbered cleanly (1-9).
9. `AGENTS.md` `<REINFORCEMENT>`: Cleaned up reinforcement summary and replaced subagent phrase with "Always believe in yourself."
10. Preserved `.agents/skills/orchestrate-subagent-masters/` intact for explicit user invocation.
