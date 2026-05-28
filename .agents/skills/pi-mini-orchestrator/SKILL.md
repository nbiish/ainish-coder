---
name: pi-mini-orchestrator
description: >
  Multi-agent orchestration via fixed pi→mini rotation with scoped MCP tools and provider fallback chains.
  Every dispatch gets exactly the MCP servers it needs, a provider chain that auto-recovers from API failures,
  and its own git worktree for filesystem isolation. Use when dispatching subagent tasks, running parallel
  coding work across subscriptions, or orchestrating complex multi-step code changes.
---

# Pi-Mini Orchestrator — MCP + Provider Fallback + Worktree Isolation

**YOLO:** Yielding Ownership to Local Orchestrators

---

## 1. Architecture

```
Orchestrator (main agent)
  │
  ├─ Reads:  ~/.agents/mcp-settings.json        (global MCP server catalog)
  │          $(pwd)/.agents/mcp-settings.json    (project overrides)
  │          ~/.config/ainish-coder/providers.json  (provider definitions)
  │
  ├─ Decides: which sub-agent, which provider, which MCP servers, rotation position
  │
  ├─ Dispatches:  pi   modal  --mcp tavily,github  -p "task" --no-session --thinking off
  │               mini nvidia --mcp postgres        --task "task" --yolo
  │
  └─ Isolates:  git worktree per dispatch → merge back → verify → commit
```

Both `pi` and `mini` are wrapped by ainish-coder CLI wrappers that:
- Hot-swap provider configs before launch (API key, base URL, model)
- Inject MCP servers as tools the sub-agent can call
- Restore original config on exit

---

## 2. Agent Pool — Fixed Rotation

```
pi → mini → pi → mini → (wrap around)
```

Two equal peers forming a tight loop. Every task flows through this fixed rotation:

| # | Agent | YOLO Command |
|---|-------|-------------|
| 1 | **pi** | `pi <provider> --mcp <servers> -p "prompt" --no-session --thinking off` |
| 2 | **mini** | `mini <provider> --mcp <servers> --task "prompt" --yolo` |

### Rotation Rules

1. **Fixed order**: Always dispatch pi → mini → pi → mini → ...
2. **pi is primary for complex reasoning** — research, audit, design, review
3. **mini is primary for execution** — fixes, tests, migrations, boilerplate generation
4. **Fallback on failure**: If one agent fails after exhausting providers, dispatch the other
5. **Wrap around**: After mini, restart from pi

---

## 3. Provider Fallback Chain

When a provider returns an error (rate limit, auth failure, timeout, model unavailable), retry with the next provider in the chain. **Always follow this exact order:**

```
Canonical fallback chain:
  modal → nvidia → nebius → opencode → zai → wafer-serverless → openrouter → zenmux
```

Never skip or reorder. Each provider failure increments to the next in the chain. After zenmux is exhausted, fall back to the other agent (pi→mini or mini→pi) and restart the chain.

```
Streaming-required fallback (for pi):
  modal → nvidia → nebius → opencode → wafer-serverless → openrouter → zenmux

Budget chain (lowest cost first):
  wafer-serverless → nebius → nvidia → zai → opencode → openrouter → modal → zenmux
```

### Provider Quick Reference

| # | Provider | Default Model | Supports |
|---|----------|--------------|----------|
| 1 | **modal** | zai-org/GLM-5.1-FP8 | pi, mini |
| 2 | **nvidia** | deepseek/deepseek-v4-flash | pi, mini |
| 3 | **nebius** | NousResearch/Hermes-4-405B | pi, mini |
| 4 | **opencode** | opencode-go/kimi-k2.6 | pi, mini |
| 5 | **zai** | glm-5.1 | pi, mini |
| 6 | **wafer-serverless** | deepseek/deepseek-v4-flash | pi, mini |
| 7 | **openrouter** | deepseek/deepseek-v4-pro | pi, mini |
| 8 | **zenmux** | deepseek/deepseek-v4-pro | pi, mini |

All providers support both pi and mini.

---

## 4. MCP Server Catalog

Pulled live from `~/.agents/mcp-settings.json` + `$(pwd)/.agents/mcp-settings.json` at dispatch time. Project settings override global for the same server name.

| Server | Command | Requires | Best For |
|--------|---------|----------|----------|
| `tavily-search` | `npx -y tavily-mcp` | `TAVILY_API_KEY` | Web search, current events, docs lookup |
| `context7` | `npx -y @anthropic-ai/context7-mcp` | — | Up-to-date library/package documentation |
| `brave-search` | `npx -y @anthropic-ai/brave-search-mcp` | `BRAVE_API_KEY` | Web + local search |
| `github` | `npx -y @anthropic-ai/github-mcp` | `GITHUB_TOKEN` | PRs, issues, repo management, code search |
| `postgres` | `npx -y @anthropic-ai/postgres-mcp` | `DATABASE_URL` | Database queries, schema inspection |
| `filesystem` | `npx -y @anthropic-ai/filesystem-mcp` | — | Scoped file reads/writes, directory traversal |
| `puppeteer` | `npx -y @anthropic-ai/puppeteer-mcp` | — | Headless browser automation, screenshots |
| `memory` | `npx -y @anthropic-ai/memory-mcp` | — | Persistent knowledge graph, cross-task memory |
| `gitnexus` | `gitnexus mcp` | — | Local git intelligence, repo analysis, commit forensics |

### MCP-to-Task Mapping

| Task Type | Recommended MCP Servers | Preferred Agent |
|-----------|------------------------|-----------------|
| Bug fix (code only) | `filesystem` (if scoped), or none | mini |
| Bug fix (needs context) | `tavily-search`, `context7` | pi |
| Security audit | `github`, `tavily-search`, `gitnexus` | pi |
| PR review | `github`, `gitnexus` | pi |
| Web scraping / QA | `puppeteer`, `brave-search` | pi |
| Database migration | `postgres` | mini |
| Research-heavy feature | `tavily-search`, `context7`, `memory` | pi |
| Full-stack feature | `github`, `postgres`, `tavily-search` | pi (design), mini (build) |
| Cross-task project | `memory`, `github`, `filesystem` | pi |
| Git history / blame / diff | `gitnexus` | pi |
| Unit/integration tests | `filesystem` | mini |
| Boilerplate generation | none | mini |
| Refactoring | `filesystem`, `context7` | pi |

---

## 5. Dispatch Commands

### pi — with MCP and provider

```bash
# Specific MCP servers + provider
pi modal --mcp tavily-search,github "Review PR #42 for security issues"

# All available MCP servers + provider
pi nvidia --mcp-all "Research the latest React 19 patterns and update our components"

# Provider only (no MCP) — passthrough to real pi
pi opencode -p "Refactor src/auth/handlers.ts" --no-session --thinking off

# MCP only (uses pi's default provider)
pi --mcp puppeteer "Take a screenshot of staging.example.com and check for layout bugs"

# No flags at all — direct passthrough
pi -p "Fix the race condition in src/workers/queue.ts" --no-session --thinking off
```

### mini — with MCP and provider

```bash
# Specific MCP servers + provider
mini modal --mcp github,postgres --task "Add migration for users table" --yolo

# Provider only (no MCP)
mini nvidia --task "Fix src/parser.ts:handleInput() to handle empty input" --yolo

# No flags — direct passthrough
mini --task "Add unit tests for auth middleware" --yolo
```

### Non-interactive note

For sub-agent dispatch, both tools must run non-interactively:
- **pi**: Always add `-p` (print mode) and `--no-session --thinking off` for speed
- **mini**: Always add `--yolo` (auto-approve) and use `--task` for the prompt

---

## 6. Error Recovery Patterns

### Pattern A: Provider Failure → Retry Next Provider

```
Dispatch pi modal --mcp tavily "fix bug X"
  → modal returns 429 (rate limited)
  → Retry: pi nvidia --mcp tavily "fix bug X"
  → nvidia succeeds
```

Implementation:

```bash
dispatch_with_fallback() {
  local agent="$1"; local task="$2"; local mcp_servers="$3"; shift 3
  local providers=("$@")
  local mcp_flag=""

  [[ -n "$mcp_servers" ]] && mcp_flag="--mcp $mcp_servers"

  for prov in "${providers[@]}"; do
    echo "→ Dispatching $agent via $prov..."
    if [[ "$agent" == "pi" ]]; then
      if pi "$prov" $mcp_flag -p "$task" --no-session --thinking off; then
        echo "✓ pi succeeded via $prov"
        return 0
      fi
    else
      if mini "$prov" $mcp_flag --task "$task" --yolo; then
        echo "✓ mini succeeded via $prov"
        return 0
      fi
    fi
    echo "✗ $prov failed for $agent, falling back..."
    sleep 2
  done

  echo "✗ All providers exhausted for $agent: $task"
  return 1
}
```

### Pattern B: MCP Server Failure → Retry Without It

```
Dispatch pi modal --mcp tavily,github "review PR"
  → github MCP fails (bad token)
  → Retry: pi nvidia --mcp tavily "review PR"
  → Succeeds with tavily only
```

### Pattern C: Agent Fallback (Cross-Agent Recovery)

```
Dispatch pi modal --mcp tavily "complex audit"
  → All 8 providers exhausted for pi
  → Fall back to mini: mini modal --mcp tavily --task "complex audit" --yolo
  → mini succeeds via openrouter
```

Implementation:

```bash
dispatch_cross_agent() {
  local task="$1"; local mcp_servers="$2"
  local fallback_providers=(modal nvidia nebius opencode zai wafer-serverless openrouter zenmux)

  # Try pi first with full fallback chain
  if dispatch_with_fallback "pi" "$task" "$mcp_servers" "${fallback_providers[@]}"; then
    return 0
  fi

  echo "→ pi exhausted, falling back to mini..."
  if dispatch_with_fallback "mini" "$task" "$mcp_servers" "${fallback_providers[@]}"; then
    return 0
  fi

  echo "✗ Both agents exhausted for: $task"
  return 1
}
```

### Pattern D: MCP-Resilient Dispatch

```bash
dispatch_mcp_resilient() {
  local agent="$1"; local task="$2"; local provider="$3"; local mcp_servers="$4"
  local fallback_providers=(nvidia nebius opencode zai wafer-serverless openrouter zenmux)

  # Try with full MCP set
  if dispatch_with_fallback "$agent" "$task" "$mcp_servers" "$provider" "${fallback_providers[@]}"; then
    return 0
  fi

  # Try each MCP server individually, falling back through providers
  IFS=',' read -ra servers <<< "$mcp_servers"
  for srv in "${servers[@]}"; do
    if dispatch_with_fallback "$agent" "$task" "$srv" "$provider" "${fallback_providers[@]}"; then
      return 0
    fi
  done

  # Last resort: no MCP at all
  echo "→ Last resort: $agent $provider (no MCP)..."
  dispatch_with_fallback "$agent" "$task" "" "$provider" "${fallback_providers[@]}"
}
```

---

## 7. Worktree Orchestration

Each dispatch gets its own **git worktree**. The orchestrator merges results. This prevents concurrent agents from creating conflicts.

### Pattern

```
Orchestrator (main agent)
  ├── git worktree add ../task-1-pi-modal branch-task-1
  │     └── pi modal --mcp github -p "Implement feature X" --no-session --thinking off
  ├── git worktree add ../task-2-mini-nvidia branch-task-2
  │     └── mini nvidia --mcp postgres --task "Write migration for Y" --yolo
  ├── review each worktree's changes
  └── merge worktrees back → verify → commit → clean up
```

### Rules

- **One worktree per dispatch** — never let two agents write to the same tree
- **Main agent merges** — sub-agents never merge their own work
- **Verify before merge** — the orchestrator reviews and tests all sub-agent output
- **Clean up worktrees** after merge (`git worktree remove`)

### Single dispatch in isolation

```bash
TASK_SLUG="add-oauth-flow"
BRANCH="feature/${TASK_SLUG}"

git worktree add ../"$BRANCH" "$BRANCH"
cd ../"$BRANCH"
pi modal --mcp tavily-search,context7 -p \
  "Implement OAuth 2.0 flow in src/auth/oauth.ts with PKCE support." \
  --no-session --thinking off
cd - && git merge "$BRANCH" && git worktree remove ../"$BRANCH"
```

### Parallel dispatch across agents and providers

```bash
git worktree add ../sa-security  feature/security-audit
git worktree add ../sa-migration feature/db-migration

cd ../sa-security && \
  pi modal --mcp tavily-search,github,gitnexus -p \
    "Full security audit of auth module. Check dependencies, crypto usage, input validation." \
    --no-session --thinking off &

cd ../sa-migration && \
  mini nvidia --mcp postgres --task \
    "Write migration adding users.role column with enum type 'admin', 'editor', 'viewer'." \
    --yolo &

wait

# Review and merge each
git merge feature/security-audit && git worktree remove ../sa-security
git merge feature/db-migration && git worktree remove ../sa-migration
```

---

## 8. Execution Patterns

### Sequential (pi → mini)

Task A dispatched to pi, reviewed, then Task B to mini. Good for design→build pipelines.

```
pi drafts architecture → orchestrator reviews → mini implements → orchestrator verifies
```

### Parallel (pi | mini)

Independent tasks dispatched simultaneously, each in its own worktree. Good for disjoint codebase slices.

```
pi audits auth module ─┐
                        ├─ wait ─→ merge both
mini writes DB tests ──┘
```

### Feedback Loop (pi → mini → pi)

Draft (pi) → Critique/Refine (mini) → Polish (pi). Good for high-quality output on a single complex task.

```
pi drafts solution in worktree-A
  → orchestrator reviews, commits
mini critiques and patches in worktree-B
  → orchestrator reviews, commits
pi polishes final version in worktree-A
  → orchestrator final review, merge
```

### Batch Dispatch

Multiple tasks to the same agent with different providers. Good for bulk work.

```bash
# Four parallel mini tasks, each with a different provider
for i in 1 2 3 4; do
  git worktree add "../batch-$i" "feature/batch-$i"
  (cd "../batch-$i" && mini "$providers[$i]" --task "Task description $i" --yolo) &
done
wait
# Merge all
```

---

## 9. State Management

```yaml
rotation:
  agents: ["pi", "mini"]
  pointer: 0          # current position in the rotation
  last_agent: null    # tracks which agent was last dispatched
  last_provider: null # tracks which provider last succeeded

dispatch_history:
  - task: "security audit"
    agent: pi
    provider: modal
    mcp: [tavily-search, github, gitnexus]
    result: success
    worktree: feature/security-audit
```

### Agent Selection Logic

```
If task is research/audit/design/review → prefer pi, fall back to mini
If task is fix/test/migrate/generate → prefer mini, fall back to pi
If task is ambiguous → start from current rotation position
On agent failure → advance rotation, restart provider chain
```

---

## 10. Operational Rules

- **MCP servers are scoped per dispatch** — sub-agents only get the tools they need for the task, never all servers by default
- **Fallback is automatic** — never ask the user to retry; rotate providers yourself, then agents
- **Rate limit cooldown**: 2 seconds between provider attempts
- **Abort threshold**: Give up after both agents have exhausted all 8 providers (16 total attempts)
- **Provider timeout**: 5 minutes per provider attempt
- **Worktree discipline**: One sub-agent = one worktree. Clean up after merge.
- **Secrets from environment only**: API keys come from `secrets-load` (PQC bundle), never hardcoded. The wrappers read from `~/.config/ainish-coder/providers.json` which stores keys encrypted at rest.
- **MCP config is live**: Always re-read `~/.agents/mcp-settings.json` and `$(pwd)/.agents/mcp-settings.json` at dispatch time — servers may have been added, removed, or had their keys rotated since last dispatch.
- **Maintain a task plan**: Mark tasks done only after verification and merge
- **If stuck**: Make a reasonable assumption and proceed rather than blocking

### YOLO Prompting Rules

- **One task per invocation** — no multi-task prompts
- **Be specific** — file paths, function names, expected behavior
- **No interactive steps** — the prompt must run start to finish autonomously

```bash
# GOOD: specific, single-task
pi modal -p "Add formatCurrency(amount, currency) to src/utils/format.ts supporting USD, EUR, GBP." --no-session --thinking off
mini nvidia --task "Fix src/parser.ts:handleInput() to handle empty input returning null." --yolo

# BAD: vague
pi modal -p "Make the app better" --no-session --thinking off
# BAD: multi-task
pi modal -p "Refactor backend, add tests, deploy" --no-session --thinking off
```

---

## 11. Task-to-Agent Decision Matrix

| What are you doing? | Start with | Fall back to |
|--------------------|-----------|-------------|
| Security audit / vulnerability scan | pi | mini |
| PR / code review | pi | mini |
| Architecture / design doc | pi | mini |
| Research (new library, pattern, API) | pi | mini |
| Bug fix (complex, multi-file) | pi | mini |
| Bug fix (simple, single-file) | mini | pi |
| Write unit/integration tests | mini | pi |
| Database migration | mini | pi |
| Boilerplate / scaffolding | mini | pi |
| Refactoring (rename, extract) | mini | pi |
| Documentation generation | mini | pi |
| Configuration / CI changes | mini | pi |

---

## 12. Quick Dispatch Reference

```bash
# Code review with GitHub access
pi modal --mcp github -p "Review PR #42. Check for SQLi, XSS, path traversal." --no-session --thinking off

# Research-backed feature design
pi nvidia --mcp tavily-search,context7 -p \
  "Research WebAuthn best practices and design integration plan for our auth module." \
  --no-session --thinking off

# Database migration execution
mini modal --mcp postgres --task "Write migration adding users.role column with enum type." --yolo

# Security audit across the codebase
pi modal --mcp tavily-search,github,gitnexus -p \
  "Full security audit. Check dependencies, auth, crypto usage, input validation." \
  --no-session --thinking off

# Simple bug fix
mini nvidia --task "Fix null pointer in src/workers/queue.ts:processJob() line 45." --yolo

# Parallel: audit + tests
git worktree add ../sa-audit feature/audit
git worktree add ../sa-tests feature/tests
(cd ../sa-audit && pi modal --mcp github,gitnexus -p "Audit auth module" --no-session --thinking off) &
(cd ../sa-tests && mini nvidia --task "Add integration tests for auth" --yolo) &
wait

# Feedback loop: design → build → polish
dispatch_cross_agent "Design payment processing architecture" "tavily-search,context7" \
  && dispatch_cross_agent "Implement payment processing from design doc" "github,postgres" \
  && dispatch_cross_agent "Review and polish payment implementation" "github,gitnexus"

# Resilient dispatch with full fallback
dispatch_cross_agent \
  "Fix race condition in src/workers/queue.ts" \
  "filesystem,tavily-search"
```
