# Orchestrated System of Agents (OSA)

> Multi-agent orchestration reference for CLI-based agentic compute. **Claude (Ralph Loop) is the mandatory Trunk Orchestrator**. All tasks must be managed via the framework files (`llms.txt`, `OSA.md`, `OSAVARS.toon`, `TODO.md`) and synchronized via **TOON** (See `TOON.md`).

---

## The Ralph-Trunk Orchestrator Pattern (SOTA 2026)

This pattern uses **Claude (Ralph Loop)** as the high-level orchestrator that maintains global state and delegates work to specialized sub-agents.

### The TOON-Guided Workflow

1.  **HISTORY**: Ralph reads **OSAVARS.toon** (formatted in [TOON.md](TOON.md)) to understand past interactions, winning solutions, and recurring issues.
2.  **PLAN**: Ralph updates `TODO.md` with a Strategic Plan based on historical context.
3.  **DELEGATE**: Ralph spawns sub-agent branches using CLI commands:
    - `gemini -y -p "{expert_directive_for_gemini}"`
    - `qwen -y "{expert_directive_for_qwen}"`
4.  **SYNC**: Sub-agents update `OSAVARS.toon` with their variables and logs.
5.  **MERGE**: Ralph reviews branch results, merges the work, and stores the final "Winning Solution" in TOON tables.

### Agent Available

| Agent |
| :--- | :--- |
| **Claude (Ralph)** | Trunk |
| **Gemini** | Branch |
| **Qwen** | Branch |
| **Opencode** | Branch |

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

### Supervisor Delegation (Ralph Loop)
```
[prompt]
Role: Engineering Supervisor
Task: Manage the development loop
Loop:
  1. Read TODO.md (Queue)
  2. Pick next pending task
  3. Execute (or delegate)
  4. Verify
  5. Update TODO.md & OSAVARS.toon
  6. Repeat until ALL_DONE
Promise: "ALL_TASKS_COMPLETE"
[/prompt]
```

---

## Appendix: Ralph Loop Directive (Trunk Capability)

**Ralph Wiggum** is your built-in autonomous loop engine. It enables you to "sleep-ship" features by running iterative cycles until a completion promise is met.

**You already have this capability installed.** Your primary role as Trunk Orchestrator is to wield this tool to execute complex, multi-step workflows without constant user hand-holding.

### Core Command: How to Invoke Your Loop

To start an autonomous work cycle, use the `/ralph-loop` command. You must define a clear prompt and a specific "completion promise" string that you will output when the job is done.

```bash
/ralph-loop "<YOUR_INSTRUCTIONS_TO_SELF>" --max-iterations <N> --completion-promise "<COMPLETION_STRING>"
```

**Parameters:**
- **`--max-iterations <N>`**: Always set this (e.g., 25 or 50) to prevent infinite loops and runaway costs.
- **`--completion-promise "<text>"`**: The exact string (e.g., "ALL_DONE") you will output to signal success and terminate the loop.

### Standard Operating Procedure (Kanban Loop)

Do not just "retry" commands. Orchestrate a **Kanban-style development loop**. Treat yourself as an engineer picking tickets from a queue.

#### 1. The 3-Layer Memory Structure
You must utilize these three files to maintain context across iterations:

1.  **`backlog.json`** (The Queue): Create/Read this for atomic, testable user stories.
2.  **`memories.toon`** (Long-term Memory): Read this for architectural decisions and coding standards.
3.  **`progress.txt`** (Short-term Memory): Write to this to log actions and pass context to your next iteration.

#### 2. The Execution Loop Logic
When you invoke `/ralph-loop`, your internal prompt should follow this logic:

```text
1. READ backlog.json to find the next 'pending' task.
2. READ memories.toon for architectural decisions.
3. IMPLEMENT the task.
4. VERIFY with tests.
5. UPDATE backlog.json (mark task as 'completed').
6. APPEND details to progress.txt.
7. IF more tasks exist, RESTART loop.
8. ELSE, output "ALL_TASKS_COMPLETE".
```

#### 3. Standard Supervisor Prompt Template
Use this command to start a robust development session:

```bash
/ralph-loop "You are a Senior Engineer. Read backlog.json. Pick the first 'pending' task. Implement it. Run tests. If successful, mark as 'done' in json and update progress.txt. If failed, log error and retry once. Output 'ALL_DONE' only when no pending tasks remain." --completion-promise "ALL_DONE" --max-iterations 50
```

### Advanced Usage Patterns

#### Refactoring Loop
For dedicated refactoring tasks, use a tighter loop:
```bash
/ralph-loop "Refactor [COMPONENT] for [GOAL]. Output REFACTORED when complete." --max-iterations 25 --completion-promise "REFACTORED"
```

#### Parallel Swarming (Git Worktrees)
To parallelize work, direct the user (or yourself via shell) to set up worktrees, then trigger loops in each:

```bash
# Example: Directing parallel UI and API work
git worktree add ../feature-ui feature/ui && cd ../feature-ui && /ralph-loop "Build UI..." --completion-promise "UI_READY" &
git worktree add ../feature-api feature/api && cd ../feature-api && /ralph-loop "Build API..." --completion-promise "API_READY" &
```

#### Cross-Agent State Injection (OSA)
Use `OSAVARS.toon` to coordinate with other agents:
*   **Write Status**: Update `OSAVARS.toon` with `{"status": "waiting_for_review"}`.
*   **Trigger Others**: This signal allows Gemini/Qwen agents to wake up and perform reviews.

### Best Practices for Orchestrators

1.  **Context Hygiene**: Your loop relies on context resets. Ensure your prompt includes all necessary instructions because previous context will be wiped between phases.
2.  **Atomic Stories**: Break tasks down.
    *   *Bad*: "Build the app."
    *   *Good*: "Create login UI", "Add Zod validation", "Connect auth API".
3.  **Cost Awareness**: Always set `--max-iterations`. If you get stuck, the loop must terminate to save resources.
4.  **Self-Correction**: If you detect a repeated failure in `progress.txt`, pause, update `memories.toon` with a fix strategy, and resume.
