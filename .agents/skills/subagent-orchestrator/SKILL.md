---
name: subagent-orchestrator
description: >
  Dispatch pi and mini sub-agents with scoped MCP tools and provider fallback chains.
  Pulls MCP server configs from ~/.agents/mcp-settings.json and $(pwd)/.agents/mcp-settings.json
  at dispatch time. Recovers from provider failures by rotating through the fallback chain.
  Use when orchestrating sub-agent work, running parallel coding tasks across subscriptions,
  or any time a sub-agent needs specific tools (web search, GitHub, browser, database).
---

# Sub-Agent Orchestrator — MCP + Provider Fallback

Dispatch **pi** and **mini** sub-agents with exactly the MCP tools they need and a provider fallback chain that recovers from API failures automatically.

---

## 1. Architecture

```
Orchestrator (Claude Code / main agent)
  │
  ├─ Reads:  ~/.agents/mcp-settings.json        (global MCP server catalog)
  │          $(pwd)/.agents/mcp-settings.json    (project overrides)
  │          ~/.config/ainish-coder/providers.json  (provider definitions)
  │
  ├─ Decides: which sub-agent, which provider, which MCP servers
  │
  └─ Dispatches:  pi   modal  --mcp tavily,github  "task"
                  mini nvidia --mcp brave-search    --task "task" --yolo
```

Both `pi` and `mini` are wrapped by ainish-coder CLI wrappers that:
- Hot-swap provider configs before launch (API key, base URL, model)
- Inject MCP servers as tools the sub-agent can call
- Restore original config on exit

---

## 2. MCP Server Catalog

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

| Task Type | Recommended MCP Servers |
|-----------|------------------------|
| Bug fix (code only) | `filesystem` (if scoped), or none |
| Bug fix (needs context) | `tavily-search`, `context7` |
| Security audit | `github`, `tavily-search`, `gitnexus` |
| PR review | `github`, `gitnexus` |
| Web scraping / QA | `puppeteer`, `brave-search` |
| Database migration | `postgres` |
| Research-heavy feature | `tavily-search`, `context7`, `memory` |
| Full-stack feature | `github`, `postgres`, `tavily-search` |
| Cross-task project | `memory`, `github`, `filesystem` |
| Git history / blame / diff | `gitnexus` |

---

## 3. Provider Fallback Chain

When a provider returns an error (rate limit, auth failure, timeout, model unavailable), retry with the next provider in the chain. **Always follow this exact order:**

```
Canonical fallback chain:
  modal → nvidia → nebius → opencode → zai → wafer-serverless → openrouter → zenmux
```

Never skip or reorder. Each provider failure increments to the next in the chain. After zenmux is exhausted, abort and report failure.

```
Streaming-required chain (for pi):
  modal → nvidia → nebius → opencode → wafer-serverless → openrouter → zenmux

Budget chain (lowest cost first, same providers):
  wafer-serverless → nebius → nvidia → zai → opencode → openrouter → modal → zenmux
```

### Provider Quick Reference

| # | Provider | Default Model | Tools |
|---|----------|--------------|-------|
| 1 | **modal** | zai-org/GLM-5.1-FP8 | pi, mini |
| 2 | **nvidia** | deepseek/deepseek-v4-flash | pi, mini |
| 3 | **nebius** | NousResearch/Hermes-4-405B | pi, mini |
| 4 | **opencode** | opencode-go/kimi-k2.6 | pi, mini |
| 5 | **zai** | glm-5.1 | pi, mini |
| 6 | **wafer-serverless** | deepseek/deepseek-v4-flash | pi, mini |
| 7 | **openrouter** | deepseek/deepseek-v4-pro | pi, mini |
| 8 | **zenmux** | deepseek/deepseek-v4-pro | pi, mini |

All providers support both pi and mini. `wafer-serverless` replaces the old `wafer` and `wafer-balance` entries — they only support serverless now.

---

## 4. Dispatch Commands

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

## 5. Error Recovery Patterns

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
  local task="$1"; shift
  local mcp_servers="$1"; shift
  local providers=("$@")
  local mcp_flag=""

  [[ -n "$mcp_servers" ]] && mcp_flag="--mcp $mcp_servers"

  for prov in "${providers[@]}"; do
    echo "→ Dispatching pi via $prov..."
    if pi "$prov" $mcp_flag -p "$task" --no-session --thinking off; then
      echo "✓ Succeeded via $prov"
      return 0
    fi
    echo "✗ $prov failed, falling back..."
    sleep 2  # brief cooldown between providers
  done

  echo "✗ All providers exhausted for: $task"
  return 1
}

# Usage
dispatch_with_fallback \
  "Fix SQL injection in src/api/search.ts" \
  "tavily-search,context7" \
  modal nvidia nebius opencode zai wafer-serverless openrouter zenmux
```

### Pattern B: MCP Server Failure → Retry Without It

```
Dispatch pi modal --mcp tavily,github "review PR"
  → github MCP fails (bad token)
  → Retry: pi nvidia --mcp tavily "review PR"
  → Succeeds with tavily only
```

Implementation:

```bash
dispatch_mcp_resilient() {
  local task="$1"; local provider="$2"; local mcp_servers="$3"
  local fallback_providers=(nvidia nebius opencode zai wafer-serverless openrouter zenmux)

  # Try with full MCP set
  if pi "$provider" --mcp "$mcp_servers" -p "$task" --no-session --thinking off 2>/dev/null; then
    return 0
  fi

  # Try each MCP server individually, falling back through providers
  IFS=',' read -ra servers <<< "$mcp_servers"
  for srv in "${servers[@]}"; do
    for prov in "$provider" "${fallback_providers[@]}"; do
      echo "→ Retrying with only $srv via $prov..."
      if pi "$prov" --mcp "$srv" -p "$task" --no-session --thinking off 2>/dev/null; then
        echo "✓ Succeeded with $srv via $prov"
        return 0
      fi
    done
  done

  # Last resort: no MCP at all
  for prov in "$provider" "${fallback_providers[@]}"; do
    echo "→ Last resort: $prov (no MCP)..."
    if pi "$prov" -p "$task" --no-session --thinking off 2>/dev/null; then
      echo "✓ Succeeded via $prov (no MCP)"
      return 0
    fi
  done

  return 1
}
```

### Pattern C: mini Fallback

```bash
mini_fallback() {
  local task="$1"; shift
  local providers=("$@")

  for prov in "${providers[@]}"; do
    echo "→ Dispatching mini via $prov..."
    if mini "$prov" --task "$task" --yolo; then
      echo "✓ mini succeeded via $prov"
      return 0
    fi
    echo "✗ $prov failed for mini..."
  done

  # Fall back to pi if mini fails all providers
  echo "→ mini exhausted, falling back to pi..."
  pi modal -p "$task" --no-session --thinking off
}
```

---

## 6. Worktree Isolation

Every sub-agent dispatch gets its own git worktree. The orchestrator merges results.

```bash
# Single sub-agent in isolation
git worktree add ../subagent-task-1 agent-task-1
cd ../subagent-task-1
pi modal --mcp github -p "Implement feature X" --no-session --thinking off
cd - && git merge agent-task-1

# Parallel sub-agents, different providers, different MCP
git worktree add ../sa-audit agent-audit
git worktree add ../sa-tests  agent-tests

cd ../sa-audit && pi modal --mcp tavily,github -p "Security audit auth module" --no-session --thinking off &
cd ../sa-tests && mini nvidia --task "Add integration tests for auth" --yolo &
wait

# Review and merge each
git merge agent-audit && git merge agent-tests
```

---

## 7. Integration with OSA Rotation

This skill slots into the existing OSA fixed-order rotation. When OSA dispatches to pi or mini, add MCP servers scoped to the task:

```
OSA rotation: gemini → claude → crush → pi → mini → opencode → kilo

pi dispatch:    pi <provider> --mcp <task-specific-servers> -p "..." --no-session --thinking off
mini dispatch:  mini <provider> --mcp <task-specific-servers> --task "..." --yolo
```

### Full OSA dispatch with MCP and fallback

```bash
osa_dispatch() {
  local task="$1"
  local mcp="${2:-}"

  local agents=(
    "gemini -p \"$task\" -y"
    "claude -p \"$task\" --dangerously-skip-permissions"
    "crush --yolo run \"$task\""
  )

  for cmd in "${agents[@]}"; do
    echo "→ $cmd"
    eval "$cmd" && return 0
  done

  # pi with fallback
  dispatch_with_fallback "$task" "$mcp" modal nvidia nebius opencode zai wafer-serverless openrouter zenmux

  # mini with fallback
  mini_fallback "$task" modal nvidia nebius opencode zai wafer-serverless openrouter zenmux
}
```

---

## 8. Operational Rules

- **MCP servers are scoped per dispatch** — sub-agents only get the tools they need for the task, never all servers by default
- **Fallback is automatic** — never ask the user to retry; rotate providers yourself
- **Rate limit cooldown**: 2 seconds between provider attempts
- **Abort threshold**: Give up after exhausting all 8 providers (modal through zenmux)
- **Worktree discipline**: One sub-agent = one worktree. Clean up after merge.
- **Secrets from environment only**: API keys come from `secrets-load` (PQC bundle), never hardcoded. The wrappers read from `~/.config/ainish-coder/providers.json` which stores keys encrypted at rest.
- **MCP config is live**: Always re-read `~/.agents/mcp-settings.json` and `$(pwd)/.agents/mcp-settings.json` at dispatch time — servers may have been added, removed, or had their keys rotated since last dispatch.

---

## 9. Quick Dispatch Reference

```bash
# Code review with GitHub access
pi modal --mcp github -p "Review PR #42. Check for SQLi, XSS, path traversal." --no-session --thinking off

# Research-backed feature build
pi nvidia --mcp tavily-search,context7 -p "Add WebAuthn support to auth module. Research latest best practices first." --no-session --thinking off

# Database migration with schema context
mini modal --mcp postgres --task "Write migration adding users.role column with enum type." --yolo

# Full-stack feature with browser testing
pi opencode --mcp github,puppeteer -p "Add checkout flow. Test in browser when done." --no-session --thinking off

# Security audit across the codebase  
pi modal --mcp tavily-search,github,gitnexus -p "Full security audit. Check dependencies, auth, crypto usage." --no-session --thinking off

# Bug fix with fallback baked in
dispatch_with_fallback \
  "Fix race condition in src/workers/queue.ts line 45" \
  "filesystem" \
  modal nvidia nebius opencode zai

# Parallel work across providers
cd ../worktree-a && pi modal --mcp github -p "Implement feature A" --no-session --thinking off &
cd ../worktree-b && mini nvidia --mcp postgres --task "Write tests for feature B" --yolo &
wait
```
