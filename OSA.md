# Orchestrated System of Agents (OSA)

> Multi-agent orchestration reference for CLI-based agentic compute. **Claude (Ralph Loop) is the mandatory Trunk Orchestrator**. All tasks must be managed via the framework files (`llms.txt`, `OSA.md`, `OSAVARS.toon`, `TODO.md`) and synchronized via **TOON**.

---

## The Ralph-Trunk Orchestrator Pattern (SOTA 2026)

This pattern uses **Claude (Ralph Loop)** as the high-level orchestrator that maintains global state and delegates work to specialized sub-agents.

### The TOON-Guided Workflow

1.  **HISTORY**: Ralph reads **OSAVARS.toon** to understand past interactions, winning solutions, and recurring issues.
2.  **PLAN**: Ralph updates `TODO.md` with a Strategic Plan based on historical context.
3.  **DELEGATE**: Ralph spawns sub-agent branches using CLI commands:
    - `gemini -y -p "{expert_directive_for_gemini}"`
    - `qwen -y "{expert_directive_for_qwen}"`
4.  **SYNC**: Sub-agents update `OSAVARS.toon` with their variables and logs.
5.  **MERGE**: Ralph reviews branch results, merges the work, and stores the final "Winning Solution" in TOON tables.

### Agent Specialization Guide

| Agent | Priority | Strengths | Best For |
| :--- | :--- | :--- | :--- |
| **Claude (Ralph)** | Trunk | Autonomous, Deep Reasoning, Multi-step Logic | **Orchestration**, Complex Refactoring, Global State |
| **Gemini** | Branch | Large Context (2M+), Large File Analysis | **Complex Implementation**, Documentation, Cross-module Logic |
| **Qwen** | Branch | High Speed, Precise Summarization | **Code Review**, Quick Fixes, Log Analysis |
| **Opencode** | Branch | Standard Patterns | Boilerplate, Simple Logic |

---

## How to Use This Document (For Orchestrator LLMs)

When a user references this document and requests a task:

1. **Initialize Trunk** — Start with `/ralph-loop` on the Trunk branch. Use framework files to track state.
2. **Consult TOON** — Read previous session logs in OSAVARS.toon to avoid repeating mistakes.
3. **Analyze the task** — Determine dependencies and parallelization opportunities.
4. **Select execution pattern** — Match task structure to Sequential, Parallel, Pipeline, or Feedback Loop.
5. **Choose agents** — Delegate to Gemini, Qwen, or Opencode in priority order.
6. **Generate executable commands** — Output ready-to-run bash commands.
7. **Iterate** — Ralph reviews outputs and loops back if requirements are not met.

---

## Execution Patterns

### 1. Sequential Execution
`Task A → Task B → Task C → Result`
Use when: Tasks have strict dependencies.

### 2. Parallel Execution
`Agent A/B/C → Merge → Result`
Use when: Tasks are independent and can run simultaneously.

### 3. Pipeline Execution
`Input → Branch A/B → specialized Result A/B`
Use when: Single input needs multiple specialized outputs.

### 4. Feedback Loop
`Generate → Validate → Refine → Result`
Use when: Iterative refinement is required until quality threshold is met.

---

## Quick Reference: Task → Pattern → Agents

| User Request | Pattern | Recommended Flow |
|--------------|---------|------------------|
| "Research X" | Parallel → Sequential | Multiple agents research → One agent synthesizes |
| "Build/Implement X" | Sequential or Pipeline | Design → Implement → Test |
| "Review X" | Parallel | Multiple agents review aspects → Merge |
| "Fix/Debug X" | Feedback Loop | Identify → Fix → Validate → Repeat |
| "Refactor X" | Feedback Loop | Refactor → Test → Validate |
| "Deep Migration" | Autonomous Loop | Ralph Loop (Claude) with completion promise |

---

## Prompt Templates for Delegation

### Standard Delegation
```
[prompt]
Role: Senior Developer (Branch)
Context: {project_context} from OSAVARS.toon
Task: {specific_task}
Reference: {relevant_files}
Output: {output_path}
Success Criteria: {success_criteria}
[/prompt]
```

### Review Delegation (Qwen)
```
[prompt]
Role: Code Reviewer
Task: Audit {target_files} for {focus_area}
Reference: {spec_path}
Format: Markdown report with Severity/Location/Fix
[/prompt]
```
