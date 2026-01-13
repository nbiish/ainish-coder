# Claude Code Ralph Loop: The Expert Prompting Guide

## Overview

**Ralph Wiggum** is not just a "retry" button—it is an autonomous execution engine for Claude Code. To use it effectively, you must stop thinking in "prompts" and start thinking in **algorithms**.

This guide covers how to construct high-fidelity prompts that turn Claude into an indefatigable engineer who sleeps-ships features while you rest.

---

## The Anatomy of a Perfect Ralph Prompt

An expert Ralph prompt contains four distinct components. Missing any one of them leads to "hallucination loops" or early exits.

### 1. The Persona (Identity & Constraints)
Define *who* Ralph is and *what* rules he must never break.
> "You are a Senior Site Reliability Engineer. You are paranoid about data loss. You NEVER delete files without backup."

### 2. The Loop Logic (The Algorithm)
Explicitly define the steps Ralph must cycle through. Do not assume he knows "how to work."
> "1. Read TODO.md. 2. Pick the top task. 3. Implement it. 4. Run tests. 5. If pass, mark done. 6. If fail, read error and retry."

### 3. The State Management (Memory)
Tell Ralph where to store his progress so he doesn't get amnesia between iterations.
> "After every step, update `OSAVARS.toon` with your current status and the last file you edited."

### 4. The Exit Condition (The Promise)
Define the **exact string** that signals the job is done.
> "Output 'ALL_SYSTEMS_GO' only when all tests pass and TODO.md is empty."

---

## Masterclass Patterns

### Pattern 1: The "Kanban Supervisor" (Best for Features)

This pattern turns Ralph into a worker pulling tickets from a queue.

**Setup**:
- `TODO.md`: List of atomic tasks (e.g., "Create button", "Style button", "Click button").

**Command**:
```bash
/ralph-loop "
ROLE: Senior Frontend Dev.
TASK:
1. READ `TODO.md` to find the next 'pending' item.
2. READ `OSA.md` for style guidelines.
3. IMPLEMENT the item.
4. VERIFY by running `npm test`.
5. UPDATE `TODO.md` (mark as 'completed').
6. LOG progress to `OSAVARS.toon`.
7. LOOP until no pending items remain.
8. OUTPUT 'FEATURE_COMPLETE'.
" --completion-promise "FEATURE_COMPLETE" --max-iterations 30
```

### Pattern 2: The "TDD Grinder" (Best for Bug Fixing)

This pattern forces Ralph to focus solely on making a test pass.

**Setup**:
- A failing test case in `tests/bug_repro.test.ts`.

**Command**:
```bash
/ralph-loop "
ROLE: Test Engineer.
GOAL: Make `tests/bug_repro.test.ts` pass.
LOOP:
1. RUN `npm test tests/bug_repro.test.ts`.
2. IF PASS: Output 'GREEN_BAR'.
3. IF FAIL: READ error logs.
4. EDIT source code to fix the specific error.
5. DO NOT remove the test.
6. RETRY.
" --completion-promise "GREEN_BAR" --max-iterations 15
```

### Pattern 3: The "Architectural Migrator" (Best for Refactors)

This pattern handles large-scale changes by keeping track of files processed.

**Command**:
```bash
/ralph-loop "
ROLE: Lead Architect.
GOAL: Migrate all `.js` files in `/src` to `.ts`.
STATE: Read/Write `MIGRATION_LOG.md` to track converted files.
LOOP:
1. FIND next unconverted `.js` file from `ls src`.
2. CHECK `MIGRATION_LOG.md` to ensure it wasn't already tried.
3. RENAME to `.ts`.
4. FIX type errors.
5. APPEND filename to `MIGRATION_LOG.md`.
6. IF no files left, Output 'MIGRATION_DONE'.
" --completion-promise "MIGRATION_DONE" --max-iterations 50
```

---

## Critical Flags & Configuration

### `--completion-promise "<string>"`
**MANDATORY**. This is the "Magic Word".
- **Bad**: "Done" (Claude might say "I have done the analysis", triggering an early exit).
- **Good**: "RALPH_SEQUENCE_COMPLETE_X99" (A unique token unlikely to be generated casually).

### `--max-iterations <int>`
**SAFETY NET**. Default is often unlimited or high.
- **Small Tasks**: 10-15.
- **Features**: 30-50.
- **Deep Research**: 20.

---

## Troubleshooting "Drunken Ralph"

If Ralph starts looping on the same error or hallucinating fixes:

1.  **The "Intervention"**:
    - Hit `Ctrl+C` to pause.
    - Manually create a file `HINT.md` with: "Hey Ralph, you're stuck on X. Try approach Y."
    - Resume/Restart the loop adding: "READ HINT.md before starting."

2.  **The "Context Flush"**:
    - If the context is polluted with 50 failed attempts, Ralph will fail the 51st.
    - **Stop**. Clear context (`/clear` or restart session).
    - Summarize state into `OSAVARS.toon`.
    - Restart Ralph with: "Resume work. State is in `OSAVARS.toon`."

---

## The "Golden Rule" of Expert Prompting

**"If you didn't write it down, Ralph doesn't know it."**

Do not assume common sense. If you want him to run `npm install` after adding a dependency, **write it in the loop steps**. If you want him to create a new file instead of overwriting, **say it**.

Ralph is a genius intern who follows instructions *literally*. Write your prompts accordingly.
