---
name: osa
description: >
  Multi-agent orchestration via fixed-order rotation across equal CLI coding agents (Gemini, Claude,
  OpenCode, mini, pi, kilo, crush). Use when dispatching subagent tasks, running parallel agent work, or
  orchestrating code changes across multiple tools. Implements YOLO mode (non-interactive) execution
  with automatic fallback on failure and git worktree isolation per subagent.
---

# OSA: Orchestrated System of Agents

**YOLO:** Yielding Ownership to Local Orchestrators

---

## Agent Pool — Fixed Rotation Order

```
gemini → claude → crush → pi → mini → opencode → kilo → (wrap around)
```

All agents are **equal peers** — multiple arms of the same thinking tool. No agent is specialized or preferred. Every task flows through the fixed rotation.

| # | Agent | YOLO Command |
|---|-------|-------------|
| 1 | **Gemini** | `gemini -p "prompt" -y` |
| 2 | **Claude** | `claude -p "prompt" --dangerously-skip-permissions` |
| 3 | **Crush** | `crush --yolo run "prompt"` |
| 4 | **pi** | `pi -p "prompt" --no-session --thinking off` |
| 5 | **mini** | `mini --task "prompt" --yolo` |
| 6 | **OpenCode** | `opencode run "prompt"` |
| 7 | **kilo** | `kilo run "prompt"` |

---

## Dispatch Rules

1. **Fixed order**: Always dispatch gemini → claude → crush → pi → mini → opencode → kilo → gemini → ...
2. **Fallback on failure**: If an agent fails, retry the **same task** with the next agent in the order
3. **Wrap around**: After kilo, restart from gemini
4. **Never repeat on success**: After a success, advance to the next agent

---

## Worktree Orchestration

Each subagent works in its own **git worktree**. The main model orchestrates all subagents and merges their changes back. This prevents concurrent agents from creating conflicts in the codebase.

### Pattern

```
Main Agent (orchestrator)
  ├── git worktree add ../task-1-agent-gemini
  │     └── gemini -p "task 1" -y
  ├── git worktree add ../task-2-agent-claude
  │     └── claude -p "task 2" --dangerously-skip-permissions
  └── merge worktrees back → verify → commit
```

### Rules

- **One worktree per subagent task** — never let two agents write to the same tree
- **Main agent merges** — subagents never merge their own work
- **Verify before merge** — the orchestrator reviews and tests all subagent output
- **Clean up worktrees** after merge

---

## YOLO Prompting

Every invocation must be non-interactive. Rules:

- **One task per invocation** — no multi-task prompts
- **Be specific** — file paths, function names, expected behavior
- **No interactive steps** — the prompt must run start to finish autonomously

### Per-Agent Syntax

```bash
# Gemini — -p for non-interactive, -y for auto-approve
gemini -p "In src/api/routes.ts add a POST /users endpoint with zod validation." -y

# Claude — -p for non-interactive, --dangerously-skip-permissions for auto-approve
claude -p "Review src/auth/middleware.ts for vulnerabilities. Output findings." --dangerously-skip-permissions

# Crush — run for non-interactive, --yolo for auto-approve permissions
crush --yolo run "Add input sanitization to src/api/handlers.ts for all POST endpoints."

# pi — -p for non-interactive, --no-session for fresh state, --thinking off for speed
pi -p "Fix race condition in src/workers/queue.ts line 45." --no-session --thinking off

# mini — --task for the description, --yolo for auto-approve
mini --task "Fix src/parser.ts:handleInput() to handle empty input." --yolo

# OpenCode — run executes non-interactively
opencode run "Validate src/ against schemas/ definitions. List mismatches."

# kilo — run executes non-interactively
kilo run "Refactor the database connection pooling logic in src/db/."
```

### Anti-Patterns

```bash
# BAD: vague
gemini -p "Make the app better" -y
# BAD: multi-task
pi -p "Refactor backend, add tests, deploy" --no-session --thinking off
# GOOD: specific, single-task
gemini -p "Add formatCurrency(amount, currency) to src/utils/format.ts supporting USD, EUR, GBP." -y
```

---

## Execution Patterns

- **Sequential**: Task A (gemini) → Task B (claude) → Task C (opencode)
- **Parallel**: Independent tasks to consecutive agents, each in its own worktree, using `&` and `wait`
- **Feedback Loop**: Draft (gemini) → Critique (claude) → Refine (opencode)

---

## State Management

```yaml
dispatch:
  order: ["gemini", "claude", "crush", "pi", "mini", "opencode", "kilo"]
  pointer: 0
  last_agent: null
```

---

## Operational Rules

- Maintain a task plan, mark tasks done only after verification
- If stuck, make a reasonable assumption and proceed
- 5 minute timeout per agent execution
- Abort if >50% agent failure rate
