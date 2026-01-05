# Orchestrated System of Agents (OSA)

> Multi-agent orchestration reference for CLI-based agentic compute. **Claude (Ralph Loop) is the mandatory Trunk Orchestrator**. All tasks must be managed via the `@OSA.md`, `@OSAVARS.md`, `@TODO.md`, and `@llms.txt` framework. Use sub-agents in order of usage priority: **Gemini → Qwen → Opencode**.

---

## How to Use This Document (For Orchestrator LLMs)

When a user references this document and requests a task:

1. **Initialize Trunk** — Start with `/ralph-loop` on the Trunk branch. Use the framework files to track state.
2. **Analyze the task** — Determine dependencies, parallelization opportunities, and output requirements.
3. **Select execution pattern** — Match task structure to Sequential, Parallel, Pipeline, or Feedback Loop.
4. **Choose agents** — Delegate 'lower' subtasks to agents in priority order (**Gemini**, then **Qwen**, then **Opencode**) to optimize for usage limits.
5. **Generate executable commands** — Output ready-to-run bash commands using the agent CLI syntax. All Claude usage MUST be via `/ralph-loop`.
6. **Define merge strategy** — Specify how outputs combine into final deliverable.
7. **Iterate** — Trunk Ralph Loop reviews outputs and loops back if requirements are not fully met.

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

### Orchestrator
| Agent | Command | Strengths | Best For |
|-------|---------|-----------|----------|
| Claude (Ralph Loop) | `/ralph-loop "{prompt}" --completion-promise "{promise}" --max-iterations {count}` | Fully autonomous, self-correcting, deep reasoning | Orchestration, deep work, refactoring, migrations |

### Agents
| Agent | Command | Strengths | Best For |
|-------|---------|-----------|----------|
| Gemini | `gemini -y -p "{prompt}"` | Multimodal, large context, strong coding | Design, documentation, complex code |
| Qwen | `qwen -y "{prompt}"` | Fast, good reasoning, generous limits | Summarization, analysis, quick tasks |
| Opencode | `opencode run "{prompt}"` | Code-focused, SOTA free model | Pure coding tasks |
| Crush | `crush run "{prompt}"` | Fast execution | Quick iterations |

### Agent Selection Guide

```
Task Type → Recommended Agent(s)
─────────────────────────────────────────────────
Orchestration         → Claude (Ralph Loop)
Research/Analysis     → Gemini (thorough), Qwen (fast)
Code Generation       → Gemini, Opencode, Qwen
Code Review           → Gemini (logic), Qwen (style)
Documentation         → Gemini, Qwen
Summarization         → Gemini, Qwen (fast)
Refactoring           → Claude (Ralph Loop), Gemini, Opencode
Multi-file Changes    → Claude (Ralph Loop), Gemini
Quick Iterations      → Gemini, Qwen, Crush
Security Audit        → Claude (Ralph Loop), Gemini
Design/Architecture   → Claude (Ralph Loop), Gemini
Deep Work/Migrations  → Claude (Ralph Loop)
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
| Opencode | Native | Isolated environment for safe code execution |

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
```

## Autonomous Deep-Work (Ralph Loop)

The Ralph Loop (via the `ralph-wiggum` plugin) allows Claude to run autonomously for up to 50 iterations, self-correcting based on tool outputs until a "completion promise" is met.

### Expert Prompting for Ralph Loop
To maximize Ralph's effectiveness, use structured prompts with explicit requirements and success criteria:

```bash
claude -p "/ralph-loop \"
Task: {task_description}

Requirements:
1. {req_1}
2. {req_2}

Success Criteria:
- All tests in {test_path} pass
- No linter errors in {src_path}
- Documentation updated in {docs_path}

Output <promise>COMPLETE</promise> when and only when all criteria are met.
\" --completion-promise \"COMPLETE\" --max-iterations 50"
```

### The Ralph-Trunk Pattern
In the OSA framework, the **Ralph Loop acts as the high-level Orchestrator (Trunk)**. It maintains the global state and iterates until the entire tree's goal is achieved.

1. **Initialize**: Start a Ralph Loop on the Trunk.
2. **Delegate**: Ralph spawns sub-agents (Gemini, Qwen, etc.) for specific branches via standard CLI commands.
3. **Verify**: Ralph reviews the sub-agent outputs.
4. **Loop-Back**: If sub-agent output is insufficient, Ralph iterates, refining the prompt for the next sub-agent call.

### Multi-Ralph Parallelism
For massive tasks, split work into separate git worktrees and run Ralph Loops in parallel:
```bash
# Terminal 1 (Auth Branch)
git worktree add ../feature-auth -b feat/auth
cd ../feature-auth && claude -p "/ralph-loop 'Implement auth...' --completion-promise 'AUTH_DONE'" &

# Terminal 2 (API Branch)
git worktree add ../feature-api -b feat/api
cd ../feature-api && claude -p "/ralph-loop 'Build REST API...' --completion-promise 'API_DONE'" &
wait
```

### State Synchronization
Ralph Loop state is tracked locally in `.claude/ralph-loop.local.md`. The OSA framework integrates this into `OSAVARS.md` for cross-agent visibility.

### Advanced Ralph-Loop SOTA (2026 Upgrade)
For elite-level autonomous orchestration, implement these high-performance patterns:

1.  **Ralph-Monitor Dashboard**: Run `ralph-monitor` in a separate terminal to track real-time loop metrics: iterations, API token consumption, file modification heatmaps, and estimated time to completion.
2.  **External Scripted Promises**: Instead of static strings, use CLI-output promises:
    ```bash
    /ralph-loop "Refactor code..." --completion-promise "SUCCESS_$(date +%Y%m%d)"
    ```
    Or wrap within a script that echoes the promise only after a test suite passes.
3.  **The "Wiggum Recovery" Protocol**: If Ralph hits a logical loop (doing the same edit 3+ times), the system should automatically inject `/reset` or `/compact` to clear context debt.
4.  **Worktree Swarming**: For massive features, split into independent modules and run parallel Ralph Loops in dedicated git worktrees:
    ```bash
    git worktree add ../swarm-api -b swarm/api
    cd ../swarm-api && ralph-loop "Build API..." --completion-promise "API_READY"
    ```
5.  **Multi-Agent Hand-off (The "Ralph-Sub" Pattern)**: Within a Ralph Loop, delegate expensive or specialized tasks to cheaper sub-agents (`gemini`, `qwen`) to preserve Claude's message limits while maintaining autonomous oversight.
6.  **Progressive Checkpoints**: Use tiered promises (`PHASE_1_DONE`, `PHASE_2_DONE`) to prevent work loss in extremely long-running migrations (50+ iterations).

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
claude -p "/ralph-loop 'Research best practices for API rate limiting, save findings to ./tmp/research.md' --completion-promise 'RESEARCH_DONE'"
qwen -y "Summarize ./tmp/research.md into key points, output to ./tmp/summary.md"
gemini -y -p "Create implementation guide from ./tmp/summary.md, output to ./docs/rate-limiting.md"

# Analyze → Fix → Test
qwen -y "Analyze ./src for security vulnerabilities, output report to ./tmp/security-audit.md"
claude -p "/ralph-loop 'Fix vulnerabilities listed in ./tmp/security-audit.md in ./src' --completion-promise 'FIXES_DONE'"
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
claude -p "/ralph-loop 'Research Go concurrency patterns, output to ./tmp/research-go.md' --completion-promise 'GO_RESEARCH_DONE'" &
wait
qwen -y "Compare and synthesize ./tmp/research-*.md into ./docs/async-comparison.md"

# Parallel code review (different aspects)
claude -p "/ralph-loop 'Review ./src/api for security issues, output to ./tmp/review-security.md' --completion-promise 'SEC_REVIEW_DONE'" &
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
claude -p "/ralph-loop 'Create API spec for user service, output to ./tmp/user-api-spec.yaml' --completion-promise 'SPEC_DONE'"

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
claude -p "/ralph-loop 'Generate authentication middleware for Express, output to ./src/middleware/auth.js' --completion-promise 'AUTH_MW_DONE'"

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
| "Deep/Massive Migration" | Autonomous Loop | Ralph Loop (Claude) with completion promise |
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
claude -p "/ralph-loop 'Deep research on {topic}: theory, history, current state. Output to ./tmp/research-deep.md' --completion-promise 'DEEP_RESEARCH_DONE'" &
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
claude -p "/ralph-loop 'Implement API from ./tmp/api-design.yaml, output to ./src/api/' --completion-promise 'API_IMPL_DONE'"
qwen -y "Generate OpenAPI docs for ./src/api/, output to ./docs/openapi.yaml" &
gemini -y -p "Generate integration tests for ./src/api/, output to ./tests/api/" &
wait
```

### User: "Review this codebase"
```bash
# Parallel multi-aspect review
claude -p "/ralph-loop 'Security audit of ./src, output to ./tmp/review-security.md' --completion-promise 'SEC_AUDIT_DONE'" &
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
claude -p "/ralph-loop 'Implement backend for ./tmp/feature-spec.md, output to ./src/backend/' --completion-promise 'BACKEND_DONE'" &
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

**When in doubt:** Start with the Trunk Orchestrator (Claude Ralph Loop), use sub-agents (Gemini → Qwen → Opencode) for execution, parallelize independent work, always define clear output paths.

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
claude -p "/ralph-loop '{task}, output to ./output/' --completion-promise 'SANDBOX_DONE'" # Deep reasoning, security
gemini -s -p "{task}, output to ./output/"        # Design, multimodal
qwen -s "{task}, output to ./output/"          # Fast, summarization

# Parallel sandbox execution (all three)
claude -p "/ralph-loop '{subtask_security}, output to ./tmp/out1.md' --completion-promise 'SB_SEC_DONE'" &
gemini -s -p "{subtask_design}, output to ./tmp/out2.md" &
qwen -s "{subtask_analysis}, output to ./tmp/out3.md" &
wait
qwen -y "Merge ./tmp/out*.md into ./output/final.md"
```

### User: "Safely analyze this untrusted repo"
```bash
# All operations in sandbox (parallel for speed)
claude -p "/ralph-loop 'Deep security analysis and threat modeling, output to ./tmp/threat-model.md' --completion-promise 'TM_DONE'" &
gemini -s -p "Analyze repo structure and architecture, output to ./tmp/structure.md" &
qwen -s "Scan for malicious patterns and obfuscation, output to ./tmp/malware-scan.md" &
wait

# Sequential deep-dive
claude -p "/ralph-loop 'Review dependencies for supply chain risks, output to ./tmp/deps-audit.md' --completion-promise 'DEPS_DONE'"
gemini -s -p "Check for data exfiltration patterns, output to ./tmp/exfil-check.md"

# Synthesis can be full-auto (no file system risk)
qwen -y "Synthesize ./tmp/*.md into comprehensive safety report, output to ./docs/repo-analysis.md"
```
