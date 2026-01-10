# Claude Code Ralph Loop Documentation

## Overview

Ralph Wiggum is a Claude Code CLI plugin enabling autonomous loops for iterative tasks like code generation and refactoring. It uses stop hooks to re-feed prompts until a completion promise is met or maximum iterations are reached.

## Installation

Install from the Anthropic marketplace within Claude Code:

```bash
/plugin install ralph-wiggum@anthropics
```

or

```bash
/plugin install ralph-wiggum@claude-code-plugins
```

Restart Claude Code after installation.[1][3][5]

## Core Command

### `/ralph-loop`

Starts an autonomous loop with a prompt:

```bash
/ralph-loop "<prompt>" --max-iterations <n> --completion-promise "<text>"
```

#### Parameters

- **`--max-iterations <n>`**: Safety limit (default: unlimited).[1][2]
- **`--completion-promise "<text>"`**: Exact phrase (e.g., "DONE") signaling completion.[1][2][5]

### Example Usage

**Simple task:**
```bash
/ralph-loop "Build a hello world API" --completion-promise "DONE" --max-iterations 10
```

Claude works, attempts exit; hook checks for promise, re-prompts if missing.[1][2][5]

### Cancel Loop

```bash
/cancel-ralph
```

## Usage Patterns

### Refactoring

```bash
/ralph-loop "Refactor [COMPONENT] for [GOAL]. Output <promise>REFACTORED</promise> when complete." --max-iterations 25 --completion-promise "REFACTORED"
```

Ensures tests pass incrementally.[1]

### Parallel with Git Worktrees

Create branches, run loops in separate terminals.[1]

### Multi-phase

Chain loops sequentially (e.g., Phase 1: models; Phase 2: API).[1]

### Batch/Overnight

Script multiple loops:

```bash
claude -p "/ralph-loop 'Task...' --max-iterations 50"
```

## How It Works

Plugin intercepts Claude's exit attempts, preserves context/files, re-injects prompt until conditions met. Ideal for iterative refinement; use limits to prevent infinite loops.[2][5]

## Best Practices

- Always set `--max-iterations` as a safety measure
- Use clear, specific completion promises
- Break complex tasks into phases
- Test with smaller iterations before running long batches
- Monitor running loops, especially overnight
- **Use `ralph-monitor`**: Run this command in a separate terminal to track iterations, cost, and progress in real-time.
- **Wiggum Recovery**: If Claude gets stuck in a logic loop, manually intervene with `/reset` to clear context debt.
- **Parallel Swarming**: Leverage `git worktree` to run independent loops simultaneously across different feature branches.
- **Tiered Promises**: Use sequential promises like `MODELS_READY` -> `API_READY` for complex migrations.

## SOTA Techniques (2026)

### Scripted Dynamic Promises
Instead of a simple string, use environment variables or dynamic strings:
```bash
/ralph-loop "Refactor..." --completion-promise "DONE_$(date +%s)"
```

### Ralph-Monitor Integration
The `ralph-monitor` utility provides a terminal UI for overseeing active loops. It helps identify when a loop has stalled or is consuming excessive tokens.

### Cross-Agent State Injection
In the OSA framework, use `OSAVARS.toon` to pass state from a Ralph Loop to other agents (`gemini`, `qwen`) and back, allowing the Loop to orchestrate a wider swarm.

## References

- [1] https://awesomeclaude.ai/ralph-wiggum
- [2] https://apidog.com/blog/claude-code-continuously-running/
- [3] https://paddo.dev/blog/ralph-wiggum-autonomous-loops/
- [4] https://www.youtube.com/watch?v=o-pMCoVPN_k
- [5] https://www.atcyrus.com/stories/ralph-wiggum-technique-claude-code-autonomous-loops
- [6] https://code.claude.com/docs/en/cli-reference
- [7] https://github.com/frankbria/ralph-claude-code
- [8] https://www.anthropic.com/engineering/claude-code-best-practices
