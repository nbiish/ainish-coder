# Claude Code Ralph Loop Documentation

## Overview

**Ralph Wiggum** is a Claude Code CLI plugin enabling autonomous loops for iterative tasks like code generation, refactoring, and feature implementation. It uses stop hooks to re-feed prompts until a completion promise is met or maximum iterations are reached.

In 2026, this has evolved from a simple "retry loop" into a sophisticated **Autonomous Agentic Workflow** engine capable of "sleep-shipping" entire features overnight.

## Core Command

### `/ralph-loop`

Starts an autonomous loop with a prompt:

```bash
/ralph-loop "<prompt>" --max-iterations <n> --completion-promise "<text>"
```

#### Parameters

- **`--max-iterations <n>`**: Safety limit (default: unlimited).
- **`--completion-promise "<text>"`**: Exact phrase (e.g., "DONE") signaling completion.

## The "Ralph" Workflow (Advanced 2026)

The "State of the Art" way to use Ralph is not just for retrying a single command, but for orchestrating a **Kanban-style development loop**. This method, popularized by developers like Ryan Carson, treats the agent as an engineer picking tickets from a queue.

### The 3-Layer Memory Architecture

To overcome context window limits and "amnesia," use three distinct files:

1.  **`backlog.json`** (The Queue): A structured list of atomic, testable user stories.
2.  **`memories.toon`** (Long-term Memory): High-level architectural decisions, conventions, and "lessons learned" that persist across the entire project.
3.  **`progress.txt`** (Short-term Memory): A log of the current loop's actions, used to pass context between immediate iterations without polluting the main context window.

### The Execution Loop

Instead of "Build this app," the workflow is:

1.  **PRD Generation**: Generate a comprehensive Product Requirement Document.
2.  **Story Extraction**: Convert the PRD into `backlog.json` containing atomic tasks.
3.  **The Loop**: Run a specialized Ralph prompt that follows this logic:

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

### Example "Supervisor" Command

```bash
/ralph-loop "You are a Senior Engineer. Read backlog.json. Pick the first 'pending' task. Implement it. Run tests. If successful, mark as 'done' in json and update progress.txt. If failed, log error and retry once. Output 'ALL_DONE' only when no pending tasks remain." --completion-promise "ALL_DONE" --max-iterations 50
```

## Usage Patterns

### 1. Refactoring (The Classic)

```bash
/ralph-loop "Refactor [COMPONENT] for [GOAL]. Output REFACTORED when complete." --max-iterations 25 --completion-promise "REFACTORED"
```

### 2. Parallel Swarming (Git Worktrees)

Use `git worktree` to run independent loops simultaneously:

```bash
# Terminal 1
git worktree add ../feature-ui feature/ui
cd ../feature-ui
/ralph-loop "Build UI components..." --completion-promise "UI_READY"

# Terminal 2
git worktree add ../feature-api feature/api
cd ../feature-api
/ralph-loop "Build API endpoints..." --completion-promise "API_READY"
```

### 3. Cross-Agent State Injection (OSA)

In the Open Swarm Architecture (OSA), use `OSAVARS.toon` to pass state.

*   **Ralph** writes to `OSAVARS.toon`: `{"status": "waiting_for_review", "last_commit": "abc1234"}`.
*   **Gemini/Qwen** agents watch this file and trigger their own workflows (e.g., code review, security scan) when the status changes.

## Best Practices & Tips

### Context Hygiene
The superpower of Ralph is the **Context Reset**. By designing your loop to exit and restart Claude's context window (if supported by your specific wrapper) or by manually clearing history between distinct phases, you prevent the "drunken stumbling" that happens when an LLM context gets too full of previous errors.

### Atomic Stories
**Do not** give Ralph a task like "Build the login page."
**Do** give Ralph tasks like:
*   "Create login UI component with email/password fields."
*   "Implement Zod validation for email field."
*   "Connect submit button to `auth.login` server action."

### Cost & Monitoring
*   **`ralph-monitor`**: Run this utility in a side terminal to track token usage and iteration count in real-time.
*   **Guardrails**: Always set `--max-iterations`. A loop stuck on a failing test can burn $50 in API credits in minutes if unchecked.

### Wiggum Recovery
If Claude gets stuck in a logic loop (repeating the same error), use the **Intervention Pattern**:
1.  Pause the loop (Ctrl+C).
2.  Manually fix the blocking issue (e.g., a typo in a config file).
3.  Add a "hint" to `memories.toon` about the fix.
4.  Resume the loop.

## References

- [1] https://awesomeclaude.ai/ralph-wiggum
- [2] https://apidog.com/blog/claude-code-continuously-running/
- [3] https://paddo.dev/blog/ralph-wiggum-autonomous-loops/
- [4] https://www.youtube.com/watch?v=RpvQH0r0ecM ("Ralph Wiggum" Agent 10x Claude Code)
- [5] https://www.atcyrus.com/stories/ralph-wiggum-technique-claude-code-autonomous-loops
- [6] https://github.com/frankbria/ralph-claude-code
