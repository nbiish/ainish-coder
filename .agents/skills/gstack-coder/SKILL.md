---
name: gstack-coder
description: >
  Multi-tool coding skill integrating gstack (Claude Code skills), pi (pi-coding-agent),
  opencode (opencode.ai), and qwen (qwen-code). Use when spawning Claude Code sessions
  for coding work, running security audits, code reviews, QA testing URLs, building features
  end-to-end, or planning before building. Also configures and orchestrates pi, opencode,
  and qwen to maximize utilization of all AI subscriptions and APIs.
---

# GStack Coder — Multi-Tool Coding Orchestration

This skill combines **gstack** (Claude Code skill pack) with **pi**, **opencode**, and **qwen** to form a complete multi-tool coding workflow. Each tool has unique strengths and subscription quotas — this skill ensures all are utilized.

---

## 1. GStack Installation & Setup

gstack is a collection of Claude Code skills by garrytan. Install once:

```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup
```

After installation, gstack provides these slash commands inside Claude Code:

| Command | Purpose |
|---------|---------|
| `/cso` | Security audit — full codebase security review |
| `/review` | Code review — detailed PR/code review |
| `/qa https://...` | QA test a URL — test a deployed endpoint |
| `/autoplan` | Auto-plan — generate implementation plan for a feature |
| `/ship` | Ship — build, test, and deploy pipeline |
| `/office-hours` | Office hours — architect/planning discussion before building |

---

## 2. Multi-Tool Coding Workflow

### Tool Inventory

| Tool | CLI | Config Location | Best For |
|------|-----|-----------------|----------|
| **Claude Code** (gstack) | `claude` | `~/.claude/` | Security audits, code review, planning, shipping |
| **pi** | `pi` | `~/.pi/agent/` | Fast non-interactive coding, extensions, themes |
| **OpenCode** | `opencode` | npm global | Non-interactive code generation, validation |
| **qwen** | `qwen` (wrapper) | `~/.qwen/settings.json` | Non-interactive coding with qwen models |

### Provider Hot-Swap (use all subscriptions)

The ainish-coder framework supports hot-swapping provider configs. Each tool can be pointed at different API providers to maximize quota usage:

```bash
# Source the hot-swap library
source bin/lib/hot_swap.sh

# Hot-swap pi to use OpenRouter
hot_swap_pi openrouter

# Hot-swap qwen to use ZenMux
hot_swap_qwen zenmux

# Then run the tool normally — it uses the swapped provider
pi -p "Add input validation to src/api/handlers.ts" --no-session --thinking off
```

Available providers: `openrouter`, `zenmux`, `zai`, `nvidia`, `wafer`, `opencode`, `kimi`

---

## 3. Coding Task Patterns

### Security Audit
```
Load gstack. Run /cso
```
Full codebase security review using gstack's security audit skill. Covers PQC compliance, injection vectors, secret leaks, and dependency vulnerabilities.

### Code Review
```
Load gstack. Run /review
```
Detailed PR/code review with line-by-line analysis, best practices checks, and improvement suggestions.

### QA Test a URL
```
Load gstack. Run /qa https://staging.example.com
```
Test a deployed URL end-to-end: functional testing, API validation, UI checks, performance baseline.

### Build a Feature End-to-End
```
Load gstack. Run /autoplan, implement the plan, then run /ship
```
Full cycle: auto-generate implementation plan → execute the plan → build & ship. The `/autoplan` breaks down the feature into tasks, and `/ship` handles testing, building, and deployment.

### Plan Before Building (No Implementation)
```
Load gstack. Run /office-hours then /autoplan. Save the plan, don't implement.
```
Architecture discussion first (`/office-hours`), then generate detailed plan (`/autoplan`). Save the plan for later implementation. No code changes.

---

## 4. OSA: Orchestrated System of Agents

When you need to dispatch work across all coding tools using fixed-order rotation:

```
gemini → claude → crush → pi → mini → opencode → kilo → (wrap)
```

### YOLO Dispatch Commands

```bash
# Sequential dispatch — each agent does one task
gemini -p "Add error handling to src/api/routes.ts" -y
claude -p "Review the error handling for edge cases" --dangerously-skip-permissions
pi -p "Add unit tests for the error handling" --no-session --thinking off
opencode run "Validate src/api/routes.ts against OpenAPI schema"
qwen zenmux "Refactor error handling to use a unified error class"
```

### Parallel Dispatch (separate worktrees)

```bash
# Each agent works on a different file in isolation
git worktree add ../task-auth agent-gemini
cd ../task-auth && gemini -p "Implement OAuth2 login flow" -y &

git worktree add ../task-payment agent-pi
cd ../task-payment && pi -p "Implement Stripe payment integration" --no-session --thinking off &

wait
# Review and merge worktrees back
```

---

## 5. Tool-Specific Configuration

### pi (pi-coding-agent)
- Config: `~/.pi/agent/settings.json`, `auth.json`, `models.json`
- Hot-swap: `hot_swap_pi <provider>`
- Non-interactive: `pi -p "prompt" --no-session --thinking off`
- Extensions: `pi -e extensions/your-extension.ts`

### OpenCode
- Install: `npm install -g @opencode-ai/opencode`
- Config: `~/.opencode/`
- Non-interactive: `opencode run "prompt"`
- Version: `opencode --version`

### qwen (qwen-code)
- Config: `~/.qwen/settings.json`
- Wrapper: `bin/qwen` (ainish-coder wrapper for provider hot-swapping)
- Hot-swap: `hot_swap_qwen <provider>`
- Direct: `qwen <provider> "prompt"` or `qwen "prompt"` (uses default)

---

## 6. Provider Configuration

Configure providers in `~/.config/ainish-coder/providers.json`:

```json
{
  "openrouter": {
    "baseUrl": "https://openrouter.ai/api/v1",
    "apiKey": "sk-or-v1-...",
    "defaultModel": "deepseek/deepseek-v4-pro",
    "tools": { "pi": true, "mini": true, "qwen": true, "codex": true }
  },
  "opencode": {
    "baseUrl": "https://opencode.ai/zen/go/v1",
    "apiKey": "sk-opencode-...",
    "defaultModel": "opencode-go/kimi-k2.6",
    "tools": { "pi": true, "mini": true, "qwen": true, "codex": true }
  },
  "kimi": {
    "baseUrl": "https://api.moonshot.ai/v1",
    "apiKey": "sk-kimi-...",
    "defaultModel": "kimi-k2.6",
    "tools": { "pi": true, "mini": true, "qwen": true, "codex": true }
  }
}
```

Each provider maps to a different subscription — rotate between them to maximize API usage.

---

## 7. Adding "Coding Tasks" to AGENTS.md

When setting up a new codebase, add this section to AGENTS.md:

```markdown
## CODING TASKS

When spawning Claude Code sessions for coding work, tell the session to use gstack skills.

### Task Patterns

- **Security audit**: "Load gstack. Run /cso"
- **Code review**: "Load gstack. Run /review"
- **QA test a URL**: "Load gstack. Run /qa https://..."
- **Build feature end-to-end**: "Load gstack. Run /autoplan, implement the plan, then run /ship"
- **Plan before building**: "Load gstack. Run /office-hours then /autoplan. Save the plan, don't implement."

### Multi-Tool Dispatch

For parallel work across subscriptions:
- **pi**: `pi -p "task" --no-session --thinking off`
- **opencode**: `opencode run "task"`
- **qwen**: `qwen <provider> "task"`

Hot-swap providers first: `source bin/lib/hot_swap.sh && hot_swap_pi openrouter`
```
