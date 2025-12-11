# Orchestrated System of Agents (OSA)

> Multi-agent orchestration reference for CLI-based agentic compute. When this document is referenced, the orchestrator LLM should use these patterns and tools to accomplish tasks with enhanced parallel intelligence.

---

## How to Use This Document (For Orchestrator LLMs)

When a user references this document and requests a task:

1. **Analyze the task** — Determine dependencies, parallelization opportunities, and output requirements
2. **Select execution pattern** — Match task structure to Sequential, Parallel, Pipeline, or Feedback Loop
3. **Choose agents** — Use the Agent Selection Guide below, respecting any user-specified preferences
4. **Generate executable commands** — Output ready-to-run bash commands using the agent CLI syntax
5. **Define merge strategy** — Specify how outputs combine into final deliverable

### User Override Handling

If the user specifies:
- **A specific tool** (e.g., "use Claude for this") → Use that tool as primary agent
- **A specific model** → Pass to the CLI tool via its flags (check `<tool> --help` for options)
- **Multiple tools** (e.g., "use Qwen and Gemini") → Distribute subtasks between specified tools
- **No preference** → Use the recommended agents from the selection guide

### Output Format

Always provide:
```bash
# Step description
<executable command>
```

For parallel tasks, use `&` and `wait`:
```bash
command1 &
command2 &
wait
# merge step
```

---

## Agents

| Agent | Command | Strengths | Best For |
|-------|---------|-----------|----------|
| Qwen | `qwen -y "{prompt}"` | Fast, good reasoning, generous limits | Summarization, analysis, quick tasks |
| Gemini | `gemini -y -p "{prompt}"` | Multimodal, large context, strong coding | Design, documentation, complex code |
| Claude | `claude --dangerously-skip-permissions --yes --recursive "{prompt}"` | Deep reasoning, safety-aware, thorough | Research, security review, architecture |
| Goose | `echo "{prompt}" \| goose` | Lightweight, scriptable | Simple automation, chaining |
| Opencode | `opencode run "{prompt}"` | Code-focused | Pure coding tasks |
| Crush | `crush run "{prompt}"` | Fast execution | Quick iterations |
| Copilot | `copilot --allow-all-tools "{prompt}"` | IDE integration | Code completion, refactoring |
| Cursor | `cursor agent --print --approve-mcps "{prompt}"` | Agentic coding | Complex multi-file changes |

### Agent Selection Guide

```
Task Type → Recommended Agent(s)
─────────────────────────────────────────────────
Research/Analysis     → Claude (thorough) or Qwen (fast)
Code Generation       → Gemini or Claude
Code Review           → Claude (security) + Qwen (style)
Documentation         → Gemini or Qwen
Summarization         → Qwen (fast) or Gemini (detailed)
Refactoring           → Cursor or Claude
Multi-file Changes    → Cursor or Claude
Quick Iterations      → Qwen or Crush
Security Audit        → Claude (primary) + Gemini (secondary)
Design/Architecture   → Claude or Gemini
```

### Model Selection

CLI tools typically support model flags — check each tool's help for available options:
```bash
<tool> --help
```

---

## Sandbox Mode

Sandbox mode runs agent commands in a restricted environment — isolated file access, no network, safer execution. Use when:
- Testing untrusted code or repos
- Running potentially destructive operations
- Working on sensitive systems
- Learning/experimenting safely

### Sandbox Support by Tool

| Agent | Sandbox Flag | Behavior |
|-------|--------------|----------|
| Gemini | `--sandbox` or `-s` | Clones repo, blocks network, restricts file access, requires confirmation for system changes |
| Claude | Default behavior (use `--dangerously-skip-permissions` to disable) | Normal mode has approval prompts; sandbox via containerization |
| Qwen | `-s` or `--sandbox` | Isolated environment for safe code execution |
| Cursor | Built-in (Enterprise) | Sandbox mode in settings; blocks network, limits to workspace + `/tmp/` |
| Copilot | Firewall-controlled environment | Coding agent runs in GitHub Actions sandbox with read-only repo access |
| Aider | Docker container | Run via `docker run` for isolation |
| Opencode | Docker container | Run via container for isolation |

### Sandbox Commands

```bash
# Claude - normal mode (has approval prompts, safe by default)
claude "{prompt}"
# Full-auto mode (skips approvals - use only in trusted repos)
claude --dangerously-skip-permissions --yes --recursive "{prompt}"

# Gemini - sandbox mode (recommended for untrusted repos)
gemini -s -p "{prompt}"
gemini --sandbox -p "{prompt}"

# Qwen - sandbox mode
qwen -s "{prompt}"
qwen --sandbox "{prompt}"

# Cursor - sandbox enabled via settings or Enterprise admin
# Commands auto-run in sandbox with workspace-only access

# Aider - run in Docker for isolation
docker run -v $(pwd):/app aider "{prompt}"

# Generic Docker isolation for any tool
docker run --rm -v $(pwd):/workspace --network none <tool-image> "{prompt}"
```

### Sandbox vs Full-Auto Mode

| Mode | Flag Example | Safety | Speed | Use Case |
|------|--------------|--------|-------|----------|
| Sandbox | `gemini -s -p` / `qwen -s` / `claude` (default) | High | Slower (confirmations) | Untrusted code, learning, sensitive systems |
| Normal | `gemini -p` / `qwen` | Medium | Medium | Standard development |
| Full-Auto | `gemini -y -p` / `qwen -y` / `claude --dangerously-skip-permissions` | Lower | Fast | Trusted repos, automation pipelines |

### Sandbox Orchestration Examples

```bash
# Safe research on untrusted repo (parallel with all three)
claude "Analyze this repo for security vulnerabilities, output to ./tmp/security-analysis.md" &
gemini -s -p "Analyze repo architecture and patterns, output to ./tmp/arch-analysis.md" &
qwen -s "Scan for code quality issues, output to ./tmp/quality-analysis.md" &
wait

# Sandbox code generation with validation
qwen -s "Generate database migration script, output to ./tmp/migration.sql"
claude "Review ./tmp/migration.sql for destructive operations, output to ./tmp/review.md"
gemini -s -p "Verify migration rollback safety, output to ./tmp/rollback-check.md"

# Mixed mode: sandbox for risky ops, full-auto for safe ops
gemini -s -p "Refactor ./src/legacy/ (potentially breaking), output to ./tmp/refactored/"
claude --dangerously-skip-permissions --yes --recursive \
  "Review refactored code for correctness, output to ./tmp/refactor-review.md"
qwen -y "Generate documentation for ./tmp/refactored/, output to ./docs/"

# Parallel sandbox execution (all three agents)
claude "Deep security audit of ./src/, output to ./tmp/security.md" &
gemini -s -p "Performance analysis of ./src/, output to ./tmp/perf.md" &
qwen -s "Dependency audit, output to ./tmp/deps.md" &
wait
```

### User Override: "Use sandbox mode with {tool}"

When user requests sandbox mode:
```bash
# If tool supports native sandbox
<tool> -s "{prompt}"
<tool> --sandbox "{prompt}"

# If tool needs container isolation
docker run --rm -v $(pwd):/workspace --network none <tool> "{prompt}"
```

---

## Execution Patterns

### 1. Sequential Execution

```
Task A → Task B → Task C → Result
```

**Use when:** Tasks have strict dependencies (output of one feeds the next)

**Pattern:**
```bash
# Step 1: Initial task
<agent1> "<task_A>, output to ./tmp/step1.md"
# Step 2: Depends on step 1
<agent2> "<task_B> using ./tmp/step1.md, output to ./tmp/step2.md"
# Step 3: Depends on step 2
<agent3> "<task_C> using ./tmp/step2.md, output to ./output/final.md"
```

**Examples:**
```bash
# Research → Summarize → Document
claude --dangerously-skip-permissions --yes --recursive \
  "Research best practices for API rate limiting, save findings to ./tmp/research.md"
qwen -y "Summarize ./tmp/research.md into key points, output to ./tmp/summary.md"
gemini -y -p "Create implementation guide from ./tmp/summary.md, output to ./docs/rate-limiting.md"

# Analyze → Fix → Test
qwen -y "Analyze ./src for security vulnerabilities, output report to ./tmp/security-audit.md"
claude --dangerously-skip-permissions --yes --recursive \
  "Fix vulnerabilities listed in ./tmp/security-audit.md in ./src"
gemini -y -p "Generate security tests for fixes in ./src, output to ./tests/security/"
```

---

### 2. Parallel Execution

```
Agent A ↘
Agent B → Merge → Result
Agent C ↗
```

**Use when:** Tasks are independent and can run simultaneously

**Pattern:**
```bash
# Parallel tasks
<agent1> "<task_A>, output to ./tmp/output-a.md" &
<agent2> "<task_B>, output to ./tmp/output-b.md" &
<agent3> "<task_C>, output to ./tmp/output-c.md" &
wait
# Merge
<agent4> "Synthesize ./tmp/output-*.md into ./output/merged.md"
```

**Examples:**
```bash
# Parallel research from multiple perspectives
qwen -y "Research Python async patterns, output to ./tmp/research-python.md" &
gemini -y -p "Research Node.js async patterns, output to ./tmp/research-node.md" &
claude --dangerously-skip-permissions --yes --recursive \
  "Research Go concurrency patterns, output to ./tmp/research-go.md" &
wait
qwen -y "Compare and synthesize ./tmp/research-*.md into ./docs/async-comparison.md"

# Parallel code review (different aspects)
claude --dangerously-skip-permissions --yes --recursive \
  "Review ./src/api for security issues, output to ./tmp/review-security.md" &
gemini -y -p "Review ./src/api for performance issues, output to ./tmp/review-perf.md" &
qwen -y "Review ./src/api for code style issues, output to ./tmp/review-style.md" &
wait
gemini -y -p "Consolidate reviews from ./tmp/review-*.md into ./docs/code-review.md"
```

---

### 3. Pipeline Execution

```
Agent A → Agent B1 → Agent C1 → Result 1
          Agent B2 → Agent C2 → Result 2
```

**Use when:** Single input needs multiple specialized outputs (branching)

**Pattern:**
```bash
# Initial shared task
<agent1> "<create_spec>, output to ./tmp/spec.md"

# Branch into parallel implementations
<agent2> "<impl_variant_1> from ./tmp/spec.md, output to ./output/variant1/" &
<agent3> "<impl_variant_2> from ./tmp/spec.md, output to ./output/variant2/" &
wait

# Optional: parallel follow-up for each branch
<agent4> "<follow_up> for ./output/variant1/" &
<agent5> "<follow_up> for ./output/variant2/" &
wait
```

**Examples:**
```bash
# Spec → Multiple implementations
claude --dangerously-skip-permissions --yes --recursive \
  "Create API spec for user service, output to ./tmp/user-api-spec.yaml"

qwen -y "Implement ./tmp/user-api-spec.yaml in Python FastAPI, output to ./impl/python/" &
gemini -y -p "Implement ./tmp/user-api-spec.yaml in Node Express, output to ./impl/node/" &
wait

qwen -y "Generate pytest tests for ./impl/python/, output to ./impl/python/tests/" &
gemini -y -p "Generate jest tests for ./impl/node/, output to ./impl/node/tests/" &
wait
```

---

### 4. Feedback Loop

```
Agent A → Agent B → Validate
         ↑          ↓
         └─ Refine ─┘ → Result
```

**Use when:** Iterative refinement required until quality threshold met

**Pattern:**
```bash
# Initial generation
<agent1> "<generate>, output to ./output/result.md"

# Validation loop
MAX_ITERATIONS=3
for i in $(seq 1 $MAX_ITERATIONS); do
  <agent2> "Validate ./output/result.md, output issues to ./tmp/validation.md"
  
  # Check if passes (customize condition)
  if grep -q "PASS" ./tmp/validation.md; then
    break
  fi
  
  <agent3> "Fix issues in ./output/result.md based on ./tmp/validation.md"
done
```

**Examples:**
```bash
# Code generation with validation
claude --dangerously-skip-permissions --yes --recursive \
  "Generate authentication middleware for Express, output to ./src/middleware/auth.js"

for i in {1..3}; do
  qwen -y "Review ./src/middleware/auth.js for security issues, output to ./tmp/validation.md"
  if grep -q "NO_ISSUES" ./tmp/validation.md; then break; fi
  gemini -y -p "Fix issues in ./src/middleware/auth.js based on ./tmp/validation.md"
done
```

---

## Quick Reference: Task → Pattern → Agents

| User Request | Pattern | Recommended Flow |
|--------------|---------|------------------|
| "Research X" | Parallel → Sequential | Multiple agents research → One agent synthesizes |
| "Build/Implement X" | Sequential or Pipeline | Design → Implement → Test |
| "Review X" | Parallel | Multiple agents review different aspects → Merge |
| "Fix/Debug X" | Feedback Loop | Identify → Fix → Validate → Repeat |
| "Document X" | Sequential | Analyze → Generate → Review |
| "Refactor X" | Feedback Loop | Refactor → Test → Validate |
| "Compare X vs Y" | Parallel | Research each → Synthesize comparison |
| "Complete this feature" | Pipeline | Spec → Parallel (frontend/backend/tests) |

---

## Prompt Templates for Agents

### Standard Task Prompt
```
[prompt]
Role: {role}
Context: {project_context}
Task: {specific_task}
Output: {output_path}
Format: {expected_format}
[/prompt]
```

### Research Prompt
```
[prompt]
Role: Technical researcher
Context: Investigating {topic} for {purpose}
Task: Research {question}, include sources and examples
Output: {output_path}
Format: Markdown with sections: Overview, Key Findings, Examples, Sources
[/prompt]
```

### Implementation Prompt
```
[prompt]
Role: Senior developer
Context: {project}, following {patterns/standards}
Task: Implement {feature} based on {spec_path}
Output: {output_directory}
Format: Production-ready code with comments
[/prompt]
```

### Review Prompt
```
[prompt]
Role: Code reviewer ({focus_area})
Context: Reviewing {target} for {purpose}
Task: Identify issues, rate severity, suggest fixes
Output: {output_path}
Format: Markdown with: Issues (severity, location, fix), Summary
[/prompt]
```

### Merge/Synthesis Prompt
```
[prompt]
Role: Technical editor
Context: Consolidating outputs from multiple agents
Task: Synthesize {input_files} into cohesive {deliverable}
Output: {output_path}
Format: {final_format}
[/prompt]
```

---

## Example Orchestrations

### User: "Research {topic} and give me a summary"
```bash
# Parallel research for breadth
claude --dangerously-skip-permissions --yes --recursive \
  "Deep research on {topic}: theory, history, current state. Output to ./tmp/research-deep.md" &
qwen -y "Research {topic}: practical applications and examples. Output to ./tmp/research-practical.md" &
gemini -y -p "Research {topic}: tools, libraries, implementations. Output to ./tmp/research-tools.md" &
wait

# Sequential synthesis
qwen -y "Synthesize ./tmp/research-*.md into executive summary with key takeaways. Output to ./docs/{topic}-summary.md"
```

### User: "Build a REST API for {feature}"
```bash
# Sequential: Design → Implement → Document → Test
gemini -y -p "Design REST API schema for {feature}, output to ./tmp/api-design.yaml"
claude --dangerously-skip-permissions --yes --recursive \
  "Implement API from ./tmp/api-design.yaml, output to ./src/api/"
qwen -y "Generate OpenAPI docs for ./src/api/, output to ./docs/openapi.yaml" &
gemini -y -p "Generate integration tests for ./src/api/, output to ./tests/api/" &
wait
```

### User: "Review this codebase"
```bash
# Parallel multi-aspect review
claude --dangerously-skip-permissions --yes --recursive \
  "Security audit of ./src, output to ./tmp/review-security.md" &
gemini -y -p "Performance analysis of ./src, output to ./tmp/review-performance.md" &
qwen -y "Code quality and maintainability review of ./src, output to ./tmp/review-quality.md" &
wait

# Merge into actionable report
gemini -y -p "Create prioritized action plan from ./tmp/review-*.md, output to ./docs/code-review-report.md"
```

### User: "Use {specific_tool} to {task}"
```bash
# Honor user's tool preference
{specific_tool_command} "{task}, output to ./output/{task_name}.md"

# If validation needed, can still use other agents
qwen -y "Validate ./output/{task_name}.md, output to ./tmp/validation.md"
```

### User: "Complete this feature for me"
```bash
# Analyze requirements
qwen -y "Analyze codebase and infer requirements for {feature}, output spec to ./tmp/feature-spec.md"

# Pipeline: parallel implementation branches
claude --dangerously-skip-permissions --yes --recursive \
  "Implement backend for ./tmp/feature-spec.md, output to ./src/backend/" &
gemini -y -p "Implement frontend for ./tmp/feature-spec.md, output to ./src/frontend/" &
qwen -y "Write unit tests for ./tmp/feature-spec.md, output to ./tests/" &
wait

# Integration validation
gemini -y -p "Verify integration between ./src/backend and ./src/frontend, report to ./tmp/integration.md"
```

---

## Meta: Orchestrator Decision Tree

```
User Request
    │
    ├─ Has dependencies? ──────────────── Yes → Sequential
    │                                      No ↓
    ├─ Multiple independent subtasks? ─── Yes → Parallel
    │                                      No ↓
    ├─ Needs multiple output variants? ── Yes → Pipeline
    │                                      No ↓
    ├─ Requires iteration/refinement? ─── Yes → Feedback Loop
    │                                      No ↓
    └─ Simple single task ─────────────── Direct execution with best-fit agent
```

**When in doubt:** Start with the most capable agent (Claude/Gemini), use Qwen for speed/volume, parallelize independent work, always define clear output paths.

---

## Sandbox Mode Decision

```
User Request
    │
    ├─ Untrusted repo/code? ────────────── Yes → Sandbox mode
    │                                       No ↓
    ├─ Potentially destructive ops? ─────── Yes → Sandbox mode
    │                                       No ↓
    ├─ Sensitive/production system? ─────── Yes → Sandbox mode
    │                                       No ↓
    ├─ Learning/experimenting? ──────────── Yes → Sandbox mode (optional)
    │                                       No ↓
    └─ Trusted automation pipeline ──────── Full-auto mode (-y)
```

### User: "Use sandbox mode to {task}"
```bash
# Single agent sandbox (choose based on task type)
claude "{task}, output to ./output/"           # Deep reasoning, security
gemini -s -p "{task}, output to ./output/"        # Design, multimodal
qwen -s "{task}, output to ./output/"          # Fast, summarization

# Parallel sandbox execution (all three)
claude "{subtask_security}, output to ./tmp/out1.md" &
gemini -s -p "{subtask_design}, output to ./tmp/out2.md" &
qwen -s "{subtask_analysis}, output to ./tmp/out3.md" &
wait
qwen -y "Merge ./tmp/out*.md into ./output/final.md"
```

### User: "Safely analyze this untrusted repo"
```bash
# All operations in sandbox (parallel for speed)
claude "Deep security analysis and threat modeling, output to ./tmp/threat-model.md" &
gemini -s -p "Analyze repo structure and architecture, output to ./tmp/structure.md" &
qwen -s "Scan for malicious patterns and obfuscation, output to ./tmp/malware-scan.md" &
wait

# Sequential deep-dive
claude "Review dependencies for supply chain risks, output to ./tmp/deps-audit.md"
gemini -s -p "Check for data exfiltration patterns, output to ./tmp/exfil-check.md"

# Synthesis can be full-auto (no file system risk)
qwen -y "Synthesize ./tmp/*.md into comprehensive safety report, output to ./docs/repo-analysis.md"
```
