# Orchestrated System of Agents (OSA)

> Multi-agent orchestration for CLI-based agentic compute. All commands run in YOLO mode (auto-approve, all tools enabled).

---

## Agents

| Agent | Command | Best For |
|-------|---------|----------|
| Qwen | `qwen -y "{prompt}"` | Fast tasks, summarization, analysis |
| Gemini | `gemini -y --model gemini-3-pro-preview -p "{prompt}"` | Design, docs, complex code, multimodal |
| Claude | `claude --dangerously-skip-permissions -p "{prompt}"` | Deep reasoning, security, architecture |
| Goose | `echo "{prompt}" \| goose run` | Lightweight automation, chaining |
| Opencode | `opencode "{prompt}"` | Pure coding tasks |
| Crush | `crush run "{prompt}"` | Quick iterations |
| Copilot | `gh copilot "{prompt}"` | Code completion, refactoring |
| Cursor | `cursor agent "{prompt}"` | Complex multi-file changes |

---

## Sandbox Mode

Use sandbox (`-s`) for untrusted code, destructive operations, or sensitive systems. Only Gemini and Qwen support native sandbox mode.

| Agent | Sandbox Flag |
|-------|--------------|
| Gemini | `-s` or `--sandbox` |
| Qwen | `-s` or `--sandbox` |

```bash
# Sandbox example
gemini -s "{prompt}"
qwen -s "{prompt}"
```

---

## Execution Patterns

### Sequential
```bash
# Task A → Task B → Task C
claude --dangerously-skip-permissions -p "Research X, output to ./tmp/research.md"
qwen -y "Summarize ./tmp/research.md, output to ./tmp/summary.md"
gemini -y --model gemini-3-pro-preview -p "Create guide from ./tmp/summary.md, output to ./docs/guide.md"
```

### Parallel
```bash
# Independent tasks → Merge
qwen -y "Research Python patterns, output to ./tmp/python.md" &
gemini -y --model gemini-3-pro-preview -p "Research Node patterns, output to ./tmp/node.md" &
claude --dangerously-skip-permissions -p "Research Go patterns, output to ./tmp/go.md" &
wait
qwen -y "Synthesize ./tmp/*.md into ./docs/comparison.md"
```

### Pipeline
```bash
# Spec → Parallel implementations
claude --dangerously-skip-permissions -p "Create API spec, output to ./tmp/spec.yaml"
qwen -y "Implement in Python from ./tmp/spec.yaml, output to ./impl/python/" &
gemini -y --model gemini-3-pro-preview -p "Implement in Node from ./tmp/spec.yaml, output to ./impl/node/" &
wait
```

### Feedback Loop
```bash
# Generate → Validate → Fix (repeat)
claude --dangerously-skip-permissions -p "Generate auth middleware, output to ./src/auth.js"
for i in {1..3}; do
  qwen -y "Review ./src/auth.js for issues, output to ./tmp/review.md"
  if grep -q "NO_ISSUES" ./tmp/review.md; then break; fi
  gemini -y --model gemini-3-pro-preview -p "Fix issues in ./src/auth.js based on ./tmp/review.md"
done
```

---

## Quick Reference

| Task | Pattern | Flow |
|------|---------|------|
| Research | Parallel → Sequential | Multiple agents research → One synthesizes |
| Build/Implement | Sequential or Pipeline | Design → Implement → Test |
| Review | Parallel | Multiple aspects → Merge |
| Fix/Debug | Feedback Loop | Identify → Fix → Validate |
| Document | Sequential | Analyze → Generate → Review |

---

## Decision Tree

```
Has dependencies?           → Sequential
Multiple independent tasks? → Parallel
Multiple output variants?   → Pipeline
Needs iteration?            → Feedback Loop
Simple single task?         → Direct execution
```

**Default:** Parallelize independent work, use Claude/Gemini for complex tasks, Qwen for speed.
