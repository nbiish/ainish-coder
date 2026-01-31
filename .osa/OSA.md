# Orchestrated System of Agents (OSA): Compute Augmentation Guide

## Overview

The **Orchestrated System of Agents (OSA)** is a framework for scaling intelligence by distributing work across specialized LLMs. This document focuses on the **"YOLO Mode"** (Yielding Ownership to Local Orchestrators) pattern—a high-autonomy, high-parallelism approach where a Main Orchestrator aggressively delegates sub-tasks to other models to maximize compute throughput.

---

## The "YOLO Mode" Philosophy

In standard agentic workflows, the orchestrator micromanages every step. In **YOLO Mode**, we trust specialized agents to execute entire sub-workflows autonomously, synchronizing only at the start (context injection) and end (result merge).

**Goal**: Convert "Time-to-Result" from Linear ($O(n)$) to Logarithmic ($O(\log n)$) by parallelizing cognitive load.

---

## The Agent Squad (The "Compute Stack")

Each agent is treated as a CLI tool with specific strengths:

| Agent | CLI Alias | YOLO Invocation (Non-Interactive) |
| :--- | :--- | :--- |
| **Claude Code** | `claude` | `claude -p "Prompt" --dangerously-skip-permissions` |
| **Gemini** | `gemini` | `gemini --yolo "Prompt"` |
| **Qwen** | `qwen` | `qwen --yolo "Prompt"` |
| **OpenCode** | `opencode` | `opencode run "Prompt"` |
| **Crush** | `crush` | `crush run "Prompt"` |

---

## The "Non-Interactive" Guarantee (IDE Agent Compatibility)

**CRITICAL RULE**: IDE agents (Trae, Windsurf, Cursor) cannot interact with TUI prompts.
All commands MUST be fully autonomous. Never launch a CLI tool in interactive mode.

**Correct Invocation Pattern**:
```bash
# Claude Code as orchestrator
claude -p "Analyze task. Run 'qwen --yolo \"Generate interface X\"'. Merge results." --dangerously-skip-permissions

# Or Gemini as orchestrator
gemini --yolo "Analyze task. Run 'qwen --yolo \"Generate interface X\"'. Merge results."
```

---

## Orchestration Protocols

### 1. The "YOLO Swarm" (Parallel Feature Build)

Instead of building a feature sequentially, Gemini spawns three agents to build parts of it simultaneously.

**Scenario**: Build a "User Dashboard" with API, UI, and DB schema.

**Gemini's Orchestration Command**:
```bash
# 1. Dispatch Database Task to OpenCode (Strict Schema)
opencode run "Create Prisma schema for UserDashboard. Models: User, Stats, Activity. Save to schema.prisma." &

# 2. Dispatch API Logic to Qwen (Fast Logic)
qwen --yolo "Write Next.js API route handlers for UserDashboard based on standard CRUD. Save to /pages/api/dashboard/." &

# 3. WAIT
wait

# 4. Merge & Verify
npm run build
```

### 2. The "Context-Heavy" Debug Loop

When a bug is too complex for standard context windows.

**Protocol**:
1.  **Gemini**: Identifies the bug but delegates the deep dive.
2.  **Gemini -> Crush**: "Read the ENTIRE `src/` directory and `logs/error.log`. Find the root cause of the race condition in `auth.ts`."
3.  **Crush**: Analyzes 100 files -> Outputs `ANALYSIS.md` with specific line numbers.
4.  **Gemini**: Reads `ANALYSIS.md` -> Fixes the code.

### 3. The "Review & Refine" Chain

High-speed code generation followed by strict auditing.

**Protocol**:
1.  **Qwen**: Generates implementation (Optimized for speed/creativity). "Write a regex to parse emails." -> `utils/parse.ts`.
2.  **OpenCode**: "Review `utils/parse.ts` for security vulnerabilities (ReDoS). Rewrite if unsafe." -> `utils/parse.safe.ts`.
3.  **Gemini**: Integrates `utils/parse.safe.ts` into the main branch.

---

## The Shared State Bus (Protocol)

To make "YOLO Mode" work, agents must not step on each other's toes. They communicate strictly via **TOON** (Token-Oriented Object Notation) in shared state files (`TODO.toon`, `PRD.toon`, `MEMORY.toon`).

**Example State Entry**:
```toon
# MEMORY.toon (Example)
task_id: feat-dashboard-01
status: in_progress

# High-density status tracking for agents
swarm[2]{agent,task,status,output,error}:
  opencode,db_schema,done,prisma/schema.prisma,
  qwen,api_routes,failed,,Missing types
```

**Rule**: Orchestrator (Gemini) reads the shared state files to decide if it needs to re-trigger a failed agent (Qwen) or merge the successful ones.

---

## How to Trigger "YOLO Mode" (as User)

You, the user, can prompt the Orchestrator to enter this mode:

> "Gemini, I need to refactor the entire `components/` folder to use Tailwind. This is a big task. **Engage YOLO Mode**. Use Crush to map the styles, Qwen to generate the new code, and you supervise the merge. Go."

**Gemini's Internal Response Plan**:
1.  Analyze `components/` size.
2.  Create `PLAN.md`.
3.  Loop:
    - Take 5 components.
    - `qwen --yolo "Convert these 5 to Tailwind"`
    - `opencode run "Verify props"`
    - Merge.
4.  Repeat.

---

## Safety & "YOLO" Limits

"YOLO" does not mean "Unsafe". It means "Unblocked".

1.  **Sandboxing**: All agents operate in the same sandbox but separate processes.
2.  **Git Worktrees**: For massive parallel changes, Gemini should assign each agent a `git worktree` so they don't get merge conflicts until the end.
    - `qwen` -> `feat/api-branch`
3.  **The "Kill Switch"**: If the shared state reports > 50% failure rate across agents, Gemini aborts the swarm and reverts to sequential mode.
