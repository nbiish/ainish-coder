# Orchestrated System of Agents (OSA): Compute Augmentation Guide

## Overview

The **Orchestrated System of Agents (OSA)** is a framework for scaling intelligence by distributing work across specialized LLMs. This document focuses on the **"YOLO Mode"** (Yielding Ownership to Local Orchestrators) pattern—a high-autonomy, high-parallelism approach where the Main Orchestrator (Claude) aggressively delegates sub-tasks to other models to maximize compute throughput.

---

## The "YOLO Mode" Philosophy

In standard agentic workflows, the orchestrator micromanages every step. In **YOLO Mode**, we trust specialized agents to execute entire sub-workflows autonomously, synchronizing only at the start (context injection) and end (result merge).

**Goal**: Convert "Time-to-Result" from Linear ($O(n)$) to Logarithmic ($O(\log n)$) by parallelizing cognitive load.

---

## The Agent Squad (The "Compute Stack")

Each agent is treated as a CLI tool with specific strengths:

| Agent | CLI Alias | Role | Superpower |
| :--- | :--- | :--- | :--- |
| **Claude** | `claude` | **Trunk Orchestrator** | State management. **MUST use `--dangerously-skip-permissions`** for autonomous runs. |
| **Gemini** | `gemini` | **Context Engine** | 2M+ token window. Use `--yolo` to skip confirmation. |
| **Qwen** | `qwen` | **Code Factory** | High-speed. Use `-y` or `--yolo` for auto-approval. |
| **Opencode** | `opencode` | **Specialist** | Specialized tasks. Use `run` with configured auto-permissions. |

---

## The "Non-Interactive" Guarantee (IDE Agent Compatibility)

**CRITICAL RULE**: IDE agents (Trae, Windsurf, Cursor) cannot interact with TUI prompts.
All commands MUST be fully autonomous. Never launch a CLI tool in interactive mode.

**Correct Invocation Pattern**:
```bash
claude --dangerously-skip-permissions -p "
  1. Analyze task.
  2. Run 'qwen -y -p \"Generate interface X\"'.
  3. Run 'gemini --yolo -p \"Review interface X\"'.
  4. Merge results.
"
```

---

## Orchestration Protocols

### 1. The "YOLO Swarm" (Parallel Feature Build)

Instead of building a feature sequentially, Claude spawns three agents to build parts of it simultaneously.

**Scenario**: Build a "User Dashboard" with API, UI, and DB schema.

**Claude's Orchestration Command**:
```bash
# 1. Dispatch Database Task to Opencode (Strict Schema)
opencode run "Create Prisma schema for UserDashboard. Models: User, Stats, Activity. Save to schema.prisma." &

# 2. Dispatch API Logic to Qwen (Fast Logic)
qwen -y -p "Write Next.js API route handlers for UserDashboard based on standard CRUD. Save to /pages/api/dashboard/." &

# 3. Dispatch UI Components to Gemini (Visual/Context aware)
gemini -y -p "Read /styles/theme.ts. Create React components for UserDashboard (StatsCard, ActivityFeed) matching our design system." &

# 4. WAIT
wait

# 5. Merge & Verify
npm run build
```

### 2. The "Context-Heavy" Debug Loop

When a bug is too complex for standard context windows.

**Protocol**:
1.  **Claude**: Identifies the bug but lacks context.
2.  **Claude -> Gemini**: "Read the ENTIRE `src/` directory and `logs/error.log`. Find the root cause of the race condition in `auth.ts`."
3.  **Gemini**: Analyzes 100 files -> Outputs `ANALYSIS.md` with specific line numbers.
4.  **Claude**: Reads `ANALYSIS.md` -> Fixes the code.

### 3. The "Review & Refine" Chain

High-speed code generation followed by strict auditing.

**Protocol**:
1.  **Qwen**: Generates implementation (Optimized for speed/creativity). "Write a regex to parse emails." -> `utils/parse.ts`.
2.  **Opencode**: "Review `utils/parse.ts` for security vulnerabilities (ReDoS). Rewrite if unsafe." -> `utils/parse.safe.ts`.
3.  **Claude**: Integrates `utils/parse.safe.ts` into the main branch.

---

## The Shared State Bus: `OSAVARS.toon`

To make "YOLO Mode" work, agents must not step on each other's toes. They communicate strictly via **TOON** (Token-Oriented Object Notation) in `OSAVARS.toon`.

**Example State Entry**:
```yaml
# OSAVARS.toon
task_id: "feat-dashboard-01"
status: "in_progress"
swarm:
  - agent: "opencode"
    task: "db_schema"
    status: "done"
    output_file: "prisma/schema.prisma"
  - agent: "qwen"
    task: "api_routes"
    status: "failed"
    error: "Missing types"
  - agent: "gemini"
    task: "ui_components"
    status: "running"
```

**Rule**: Orchestrator (Claude) reads this file to decide if it needs to re-trigger a failed agent (Qwen) or merge the successful ones.

---

## How to Trigger "YOLO Mode" (as User)

You, the user, can prompt the Orchestrator to enter this mode:

> "Claude, I need to refactor the entire `components/` folder to use Tailwind. This is a big task. **Engage YOLO Mode**. Use Gemini to map the styles, Qwen to generate the new code, and you supervise the merge. Go."

**Claude's Internal Response Plan**:
1.  Analyze `components/` size.
2.  Create `PLAN.md`.
3.  Loop:
    - Take 5 components.
    - `qwen "Convert these 5 to Tailwind"`
    - `opencode "Verify props"`
    - Merge.
4.  Repeat.

---

## Safety & "YOLO" Limits

"YOLO" does not mean "Unsafe". It means "Unblocked".

1.  **Sandboxing**: All agents operate in the same sandbox but separate processes.
2.  **Git Worktrees**: For massive parallel changes, Claude should assign each agent a `git worktree` so they don't get merge conflicts until the end.
    - `gemini` -> `feat/ui-branch`
    - `qwen` -> `feat/api-branch`
3.  **The "Kill Switch"**: If `OSAVARS.toon` reports > 50% failure rate across agents, Claude aborts the swarm and reverts to sequential mode.
