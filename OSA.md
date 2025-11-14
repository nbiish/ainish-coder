# Execution Patterns

## Sequential Execution

```markdown
Task A → Task B → Task C → Result
```

**Use when:** Tasks have strict dependencies

## Parallel Execution

```markdown
Agent A ↘
Agent B → Merge → Result
Agent C ↗
```

**Use when:** Tasks are independent

### Pipeline Execution

```markdown
Agent A → Agent B1 → Agent C1 → Result 1
         Agent B2 → Agent C2 → Result 2
```

**Use when:** Multiple outputs needed

## Feedback Loop

```markdown
Agent A → Agent B → Validate
         ↑          ↓
         └─ Refine ─┘ → Result
```

**Use when:** Iterative refinement required

## Compile Prompt

```markdown
[prompt]
Role:
Context:
Task:
[/prompt]

```

## Agents (Listed in order of skill)

[Qwen] -> `qwen -y "{prompt}"`
[Gemini] -> `gemini -y "{prompt}"`
[Copilot] -> `copilot --allow-all-tools "{prompt}"`
[Cursor] -> `cursor agent --print --approve-mcps "{prompt}"`
[Goose] -> `echo "{prompt}" | goose`
[Opencode] -> `opencode run "{prompt}"`
[Crush] -> `crush run "{prompt}"`
