# OSA: Orchestrated System of Agents

## Agent CLI Commands

| Agent | Command | Use Case | Priority |
|-------|---------|----------|----------|
| **Gemini** | `gemini --yolo "prompt"` | Orchestration, planning, merging | 1 |
| **Qwen** | `qwen --yolo "prompt"` | Fast code generation | 2 |
| **OpenCode** | `opencode run "prompt"` | Schema validation, security | 3 |
| **Crush** | `crush run "prompt"` | Security audit, code review | 4 |
| **Claude** | `claude -p "prompt" --dangerously-skip-permissions` | Architecture, QA | 5 |

## Core Rules

1. **Non-Interactive Only**: All commands must run autonomously—no TUI prompts
2. **Parallel Execution**: Use `&` and `wait` for concurrent agent tasks
3. **State Sync**: Agents share state via `.toon` files (MEMORY.toon, TODO.toon)

## Orchestration Patterns

### Parallel Build
```bash
opencode run "Create schema" &
qwen --yolo "Write API routes" &
crush run "Analyze components" &
wait
```

### Debug Chain
1. **Crush**: Analyze codebase → `ANALYSIS.md`
2. **Qwen**: Implement fix
3. **OpenCode**: Verify

### Review Chain
1. **Qwen**: Generate code (speed)
2. **OpenCode**: Audit for security
3. **Gemini**: Merge

## State File Format
```toon
task_id: feat-01
swarm[2]{agent,task,status}:
  qwen,api,done
  opencode,schema,failed
```

## Safety
- Use `git worktree` for parallel changes
- Abort swarm if >50% agent failure rate
