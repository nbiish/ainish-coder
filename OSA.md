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

Use sandbox (`-s`) to isolate work from your main codebase. Keeps experiments, research, and risky operations contained.

| Agent | Sandbox Flag |
|-------|--------------|
| Gemini | `-s` or `--sandbox` |
| Qwen | `-s` or `--sandbox` |

```bash
# Basic sandbox execution
gemini -s "{prompt}"
qwen -s "{prompt}"
```

### When to Use Sandbox

| Use Case | Why Sandbox |
|----------|-------------|
| Research & exploration | Avoid polluting working directory with temp files |
| Untrusted code execution | Isolate potentially harmful operations |
| Destructive operations | Test `rm`, migrations, schema changes safely |
| Dependency experiments | Try new packages without affecting project |
| Prototype iterations | Rapid experimentation without git noise |
| Security testing | Run vulnerability scans in isolation |
| Data transformations | Process sensitive data without leaking to main repo |

### Sandbox Patterns

#### Research Sandbox
```bash
# Offload research to sandbox, pull only final artifacts
qwen -s "Research OAuth2 implementations, create comparison matrix, output to ./research/oauth2.md"
# Review in sandbox, then copy approved content
cp ~/.sandbox/research/oauth2.md ./docs/research/
```

#### Experimentation Sandbox
```bash
# Test breaking changes in isolation
gemini -s "Refactor auth module to use JWT, test all edge cases, output to ./src/auth/"
# Validate before promoting
qwen -s "Run test suite on ./src/auth/, output results to ./test-results.md"
# If passing, merge to main codebase
```

#### Prototype Pipeline
```bash
# Build prototype in sandbox
gemini -s "Create REST API prototype for user service, output to ./prototype/"
# Iterate without cluttering main repo
for i in {1..5}; do
  qwen -s "Review ./prototype/ for improvements, apply fixes"
done
# Promote validated code
rsync -av ~/.sandbox/prototype/ ./src/services/user/
```

#### Parallel Sandbox Research
```bash
# Multiple research tracks in isolation
qwen -s "Research GraphQL patterns, output to ./research/graphql.md" &
gemini -s "Research gRPC patterns, output to ./research/grpc.md" &
wait
# Synthesize in sandbox, export summary
qwen -s "Compare ./research/*.md, create recommendation in ./research/api-decision.md"
```

### Sandbox Directory Structure

```
~/.sandbox/           # Default sandbox root (isolated from project)
├── research/         # Research outputs
├── experiments/      # Code experiments
├── prototypes/       # Rapid prototypes
├── test-runs/        # Test execution artifacts
└── tmp/              # Ephemeral scratch space
```

### Sandbox Workflow

```
1. Offload → Execute in sandbox
2. Validate → Review outputs in isolation
3. Promote → Copy approved artifacts to main codebase
4. Cleanup → Purge sandbox periodically
```

### Cleanup

```bash
# Clear sandbox after promoting artifacts
rm -rf ~/.sandbox/*

# Or selective cleanup
rm -rf ~/.sandbox/experiments/
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