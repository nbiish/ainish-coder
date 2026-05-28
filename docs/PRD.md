# ainish-coder — Product Requirements Document

**Version**: 1.2.0  
**Status**: Iterating (living document)  
**Last updated**: 2026-05-24  
**Steward**: ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [User Personas](#3-user-personas)
4. [Functional Requirements](#4-functional-requirements)
5. [Non-Functional Requirements](#5-non-functional-requirements)
6. [Architecture](#6-architecture)
7. [Component Inventory](#7-component-inventory)
8. [Provider Switching System](#8-provider-switching-system)
9. [Interactive CLI (`--cli`)](#9-interactive-cli---cli)
10. [Skills System](#10-skills-system)
11. [OSA Framework](#11-osa-framework)
12. [Security Posture](#12-security-posture)
13. [Milestones & Roadmap](#13-milestones--roadmap)
14. [Success Criteria](#14-success-criteria)
15. [Risks & Mitigations](#15-risks--mitigations)
16. [Glossary](#16-glossary)

---

## 1. Executive Summary

**ainish-coder** is a modular, open-source configuration-and-skills deployment system for AI coding assistants. It standardizes agent behavior across 10+ IDE extensions and CLI tools via the `AGENTS.md` standard, ships 18 production-grade security and domain-expertise skill packs, and enables autonomous multi-agent execution through the OSA (Orchestrated System of Agents) framework.

The tool is:

- **Self-hosted** — no cloud dependency, no SaaS telemetry
- **Zero Trust by default** — every configuration is hardened against OWASP LLM Top 10, OWASP Agentic Top 10 (ASI 2026), and OWASP Agentic Skills Top 10 (AST10 2026)
- **PQC-native** — FIPS 203/204/205 compliance, banned-classical-crypto enforcement
- **Indigenously stewarded** — built under tribal sovereignty protections and the 8th Fire Mission

**Core value proposition**: One CLI tool that deploys your agent rules, your security posture, your skills, and your multi-agent framework to any project directory — then hot-swaps your API providers across every coding tool so you maximize every subscription.

---

## 2. Problem Statement

### 2.1 Current State

Developers using multiple AI coding agents face:

1. **Config fragmentation** — Each tool (Pi, Codex, mini-swe-agent, Qwen, Claude Code) has its own config schema, location, and secrets format. Switching a provider means editing 4+ files manually.
2. **Security inconsistency** — Repository-level agent instructions (`AGENTS.md`) vary wildly in quality. Most lack PQC guidance, input-validation requirements, or MCP hardening directives.
3. **Skill duplication** — Domain expertise (code security, LLM security, browser automation) is rewritten per-project instead of deployed as shareable, versioned packs.
4. **Subscription underutilization** — Users hold 5–7 API subscriptions but default to one tool with one provider because switching is friction-heavy.
5. **No multi-agent orchestration** — No standard way to dispatch work across Claude, Gemini, Pi, Codex, mini, Qwen, and OpenCode in a coordinated rotation with fallback.

### 2.2 Target State

A single CLI tool (`ainish-coder`) that:

- Deploys a hardened `AGENTS.md` + `.gitignore` + `llms.txt` to any project in one command
- Ships 18 versioned skill packs for security, automation, research, and creative work
- Hot-swaps provider configs across Pi, Codex, mini, and Qwen with a single menu selection
- Provides an interactive menu (`--cli`) for zero-memorization tool+provider selection
- Guarantees original configs are restored on exit (never touches defaults permanently)
- Runs a security gate (`security_gate.py`) for PQC and zero-trust compliance scanning

---

## 3. User Personas

| Persona | Needs | Primary Commands |
|---------|-------|-----------------|
| **Solo Developer** | Quick setup of agent rules in a new project | `--rules`, `--llms-txt`, `--gitignore` |
| **Security Engineer** | PQC compliance, secret scanning, hardened configs | `--secure`, `--local-security`, `--github-actions` |
| **Multi-Subscription User** | Rotate through OpenRouter, ZenMux, ZAI, NVIDIA, Kimi, Wafer, OpenCode | `--cli`, `pi <provider>`, `codex <provider>` |
| **Agent Orchestrator** | Dispatch work across 7+ coding agents in parallel | `--skills` (OSA), `--unlock` |
| **Open-Source Maintainer** | Standardize contributor agent behavior | `--rules`, `--template-agent` |

---

## 4. Functional Requirements

### 4.1 Core Deployment Commands

| Command | Deploys | Target |
|---------|---------|--------|
| `ainish-coder --rules [DIR]` | `AGENTS.md`, `.gitignore` | Project root |
| `ainish-coder --agents [DIR]` | `AGENTS.md` only | Project root |
| `ainish-coder --llms-txt [DIR]` | `llms.txt` | Project root |
| `ainish-coder --secure [DIR]` | `AGENTS_CODE_SECURITY.md` (code security standards), `AGENTS_LLM_SECURITY.md` (LLM & agentic security standards) | Project root |

**Requirement**: `--rules` must NEVER deploy `llms.txt`. `llms.txt` is a separate `--llms-txt` command. This separation is enforced by code and verified by tests.

**Note on `--secure`**: The security docs (`AGENTS_CODE_SECURITY.md`, `AGENTS_LLM_SECURITY.md`) are standalone, production-grade distillations of the deeper skill packs. They are versioned and improve with every iteration. The underlying skills (`.agents/skills/code-security/`, `.agents/skills/llm-security/`, `.agents/skills/production-security/`) provide the full procedural checklists and language-specific implementations.

### 4.2 Utility Commands

| Command | Deploys |
|---------|---------|
| `--gitignore [DIR]` | Comprehensive `.gitignore` |
| `--critical [DIR]` | `critical.md` (critical protocols) |
| `--license [DIR]` | `LICENSE` file |
| `--scrolls [DIR]` | `.scrolls/` directory (vital texts, expanded prompts) |
| `--mcp-recipes [DIR]` | MCP server recipe templates to `mcp_recipes/` |
| `--signals [DIR]` | `.signals/` signal detection configs |
| `--skills [DIR]` | All 18 skill packs to `.agents/skills/` |
| `--unlock [DIR]` | Pliny Research collection (AI transparency) |
| `--template-agent [DIR]` | Template agent prompt framework |

### 4.3 Security Commands

| Command | Deploys |
|---------|---------|
| `--local-security [DIR]` | Git hooks + `.ainish/scripts/` for local secret protection |
| `--github-actions [DIR]` | CI/CD workflows: secret scanning, CodeQL, ZAP, PQC audit |

### 4.4 Provider-Switching Wrappers

Four wrapper scripts live in `bin/`: `pi`, `codex`, `mini`, `qwen`. Claude Code is configured via `~/.claude/settings.json` env vars (hot-swapped by the `--cli` flow, not a standalone wrapper).

**Usage**: `<wrapper> <provider> [args...]`

**Behavior**:
1. Read `~/.config/ainish-coder/providers.json` for provider credentials
2. If `<provider>` matches a known provider, hot-swap the tool's config
3. If `<provider>` is not recognized or omitted, passthrough to the real binary unchanged
4. Register an EXIT trap to restore the original config files on exit
5. Do NOT use `exec` — the EXIT trap must fire

**Supported providers**: openrouter, zenmux, zai, nvidia, wafer, wafer-balance, opencode, kimi

**Compatibility matrix** (enforced by `tools.<name>` fields in `providers.json`):

| Tool | openrouter | zenmux | zai | nvidia | wafer | wafer-balance | opencode | kimi |
|------|:----------:|:------:|:---:|:------:|:-----:|:-------------:|:--------:|:----:|
| pi   |     ✓      |   ✓    |  ✓  |   ✓    |   ✓   |      ✓        |    ✓     |  ✓   |
| mini |     ✓      |   ✓    |  ✓  |   ✓    |   ✓   |      ✓        |    ✓     |  ✓   |
| qwen |     ✓      |   ✓    |  ✓  |   ✓    |   ✓   |      ✓        |    ✓     |  ✓   |
| codex|     ✓      |   ✓    |  ✗  |   ✓    |   ✓   |      ✓        |    ✓     |  ✓   |
| claude|    ✗      |   ✓    |  ✗  |   ✗    |   ✗   |      ✗        |    ✗     |  ✗   |

**Requirement**: Every hot-swap MUST create a `.ainish-backup` of the original config and restore it on EXIT. The user's default configs are never permanently altered.

### 4.5 Interactive CLI (`--cli`)

Launched via `ainish-coder --cli`. See [Section 9](#9-interactive-cli---cli) for full specification.

### 4.6 Security Gate

`bin/security_gate.py` scans the repository for:
- Banned classical crypto patterns (RSA, ECDSA, etc.)
- Unsanitized path usage
- Hardcoded secrets

Excluded directories: `.git`, `.venv`, `__pycache__`, `node_modules`, `pliny-research`, `.signals-creepersweeper`, `scrolls-lab`, `.agents`, `.signals`, `.github`

---

## 5. Non-Functional Requirements

| Category | Requirement |
|----------|-------------|
| **Language** | Bash 4.0+ (POSIX-compatible where possible) |
| **Dependencies** | Python 3.8+ for `security_gate.py` and provider JSON parsing |
| **Platform** | macOS, Linux. WSL2 supported. |
| **Startup time** | `< 500ms` for `--help`/`--version`; `< 2s` for `--cli` (excluding `providers.json` parse) |
| **Exit safety** | 100% of hot-swapped configs MUST be restored on any exit path (normal, SIGINT, error) |
| **Idempotency** | `--rules`, `--skills`, and all deploy commands must be safe to run repeatedly |
| **No telemetry** | Zero outbound network calls from the tool itself (except when launching real binaries) |
| **Config isolation** | Provider secrets live in `~/.config/ainish-coder/providers.json` only, never in the repo |

---

## 6. Architecture

### 6.1 Atomic Design Pattern

```
dna/
├── atoms/         # Core utilities: colors, paths, validation, file ops, backup, security
├── molecules/     # Single-purpose deployment functions (one per command)
└── proteins/      # Higher-level orchestration scripts
```

**Principle**: Atoms never call molecules. Molecules never call each other. The CLI script (`bin/ainish-coder`) is the sole orchestrator.

### 6.2 Directory Layout

```
ainish-coder/
├── AGENTS.md                     # Universal agent instructions (active, deployed by --rules)
├── llms.txt                      # Machine-readable project context
│
├── bin/
│   ├── ainish-coder              # Main CLI entry point
│   ├── pi                        # Pi wrapper (provider hot-swap)
│   ├── codex                     # Codex wrapper (provider hot-swap)
│   ├── mini                      # mini-swe-agent wrapper (provider hot-swap)
│   ├── qwen                      # qwen-code wrapper (provider hot-swap)
│   ├── security_gate.py          # PQC & zero-trust compliance scanner
│   └── lib/
│       ├── providers.sh          # Reads providers.json; provider_read(), provider_has()
│       └── hot_swap.sh           # Config backup/rewrite/restore; EXIT trap registration
│
├── dna/
│   ├── atoms/                    # 11 core utilities
│   ├── molecules/                # 20 deployment + CLI functions
│   └── proteins/
│       └── install.sh            # Symlink-based system-wide installer
│
├── .agents/skills/               # 18 versioned skill packs
├── .scrolls/                     # Ghost Layer Codex & 8th Fire Protocols
├── .signals/                     # Signal detection reference
├── .signals-creepersweeper/      # Creepersweeper signal docs
├── mcp_recipes/                  # MCP server recipes
├── pliny-research/               # AI transparency research
├── scrolls-lab/                  # Recursive sub-agent optimization pipeline
├── reference_codebases/          # Reference implementations
└── scripts/
    └── setup-hooks.sh            # Git hooks setup
```

### 6.3 Data Flow: Provider Hot-Swap

```
User                         ainish-coder/cli          hot_swap.sh              ~/.config/ainish-coder/
  │                                │                        │                         │
  │  ainish-coder --cli            │                        │                         │
  ├───────────────────────────────>│                        │                         │
  │                                │  source hot_swap.sh    │                         │
  │                                ├───────────────────────>│  read providers.json    │
  │                                │                        ├────────────────────────>│
  │                                │                        │<────────────────────────┤
  │  pick tool+provider            │                        │                         │
  │<──────────────────────────────>│                        │                         │
  │                                │  hot_swap_pi("zai")    │                         │
  │                                ├───────────────────────>│                         │
  │                                │                        │  cp config .ainish-backup│
  │                                │                        │  rewrite config for zai │
  │                                │                        │  trap _restore EXIT     │
  │                                │<───────────────────────┤                         │
  │  launch pi <args>              │                        │                         │
  │<───────────────────────────────┤                        │                         │
  │                                │                        │                         │
  │  exit                          │  EXIT trap fires       │                         │
  │                                │  _cli_cleanup()        │                         │
  │                                │  → _ainish_restore_all │                         │
  │                                │    mv .ainish-backup   │                         │
  │                                │      → original config │                         │
  │                                │  → stty sane           │                         │
```

### 6.4 Provider Config Schema (`providers.json`)

```json
{
  "<provider-name>": {
    "baseUrl": "https://api.example.com/v1",
    "apiKey": "sk-...",
    "defaultModel": "provider/model-name",
    "envKey": "PROVIDER_API_KEY",
    "note": "Optional human description of this provider config",
    "tools": {
      "pi": true,
      "mini": true,
      "qwen": true,
      "codex": true
    },
    "modelAliases": {
      "pi": "bare-model-name",
      "mini": "openai/provider/model-name",
      "qwen": "provider/model-name",
      "codex": "provider/model-name",
      "claude": "provider/model-name"
    }
  }
}
```

- `baseUrl`: OpenAI-compatible completions endpoint
- `apiKey`: API key (never logged or displayed in full)
- `defaultModel`: Canonical model ID with provider prefix (e.g., `deepseek/deepseek-v4-pro`)
- `envKey`: Environment variable name for the API key (used by codex/qwen)
- `note`: Optional human-readable description of this provider configuration
- `tools.<name>`: Boolean gate controlling which wrapper supports this provider
- `modelAliases.<tool>`: **Planned** — per-tool model name translations. Currently derived implicitly by hot-swap functions; making these explicit in providers.json is the next iteration. Until then, translations are:
  - **pi**: strips provider prefix for `defaultModel`, uses full `provider/model` in `enabledModels`
  - **mini**: prepends `openai/` to the model name
  - **qwen**: uses model name as-is
  - **codex**: uses model name as-is
  - **claude**: uses model name as-is via env var

---

## 7. Component Inventory

### 7.1 Atoms (`dna/atoms/`) — 11 files

| File | Purpose |
|------|---------|
| `colors.sh` | ANSI color codes and print helpers (`print_success`, `print_error`, `print_warning`, `print_info`, `print_header`) |
| `paths.sh` | `$REPO_DIR`, `get_project_root()`, `ensure_dir()` |
| `validation.sh` | `validate_target_dir()`, `require_agents_md()`, `safe_mkdir()` |
| `file_operations.sh` | `copy_with_backup()`, `symlink_with_backup()`, `safe_remove()` |
| `backup.sh` | `create_backup()`, `restore_backup()`, `clean_old_backups()` |
| `ignore_patterns.sh` | Patterns for `.gitignore` generation |
| `config.sh` | Config file utilities |
| `file_utils.sh` | Additional file utilities |
| `security_scan.sh` | Security scanning helpers |
| `sanitize-settings.sh` | Settings sanitization |
| `secret-protection-help.sh` | Secret protection guidance |

### 7.2 Molecules (`dna/molecules/`) — 20 files

| File | Purpose |
|------|---------|
| `help.sh` | `show_help()`, `show_version()` |
| `cli_interface.sh` | Full interactive CLI menu system (see Section 9) |
| `deploy_agents.sh` | Copy `AGENTS.md` to target |
| `deploy_gitignore.sh` | Copy `.gitignore` to target |
| `deploy_llms_txt.sh` | Copy `llms.txt` to target |
| `deploy_skills.sh` | Copy all 18 skill packs to `.agents/skills/` |
| `deploy_critical.sh` | Copy `critical.md` |
| `deploy_license.sh` | Copy `LICENSE` |
| `deploy_scrolls.sh` | Copy `.scrolls/` directory |
| `deploy_signals.sh` | Copy `.signals/` directory |
| `deploy_mcp_recipes.sh` | Copy MCP recipe templates |
| `deploy_mcp.sh` | MCP deployment |
| `deploy_template_agent.sh` | Template agent prompt framework |
| `deploy_unlock.sh` | Pliny Research collection |
| `deploy_commands.sh` | Slash commands/workflows for AI tools |
| `deploy_github_actions.sh` | GitHub Actions CI/CD workflows |
| `deploy_local_security.sh` | Local git hooks + scripts for secret protection |
| `clear_all_rules.sh` | Remove all deployed rules |
| `setup_shell.sh` | Shell setup |
| `setup-secret-protection.sh` | Secret protection setup |

### 7.3 Proteins (`dna/proteins/`) — 1 file

| File | Purpose |
|------|---------|
| `install.sh` | Wrapper for system-wide symlink installation to `/usr/local/bin` |

### 7.4 Wrapper Binaries (`bin/`) — 5 files

| File | Purpose |
|------|---------|
| `ainish-coder` | Main CLI — sources atoms, molecules, routes commands |
| `pi` | Pi coding agent wrapper — `hot_swap_pi <provider>`, then launch real pi |
| `codex` | Codex agent wrapper — `hot_swap_codex <provider>`, then launch real codex |
| `mini` | mini-swe-agent wrapper — `hot_swap_mini <provider>`, then launch real mini |
| `qwen` | qwen-code wrapper — `hot_swap_qwen <provider>`, then launch real qwen |

### 7.5 Library (`bin/lib/`) — 2 files

| File | Purpose |
|------|---------|
| `providers.sh` | `provider_read()`, `provider_list()`, `provider_has()`, `provider_supports()` |
| `hot_swap.sh` | Per-tool config backup/rewrite/restore, EXIT trap registration |

---

## 8. Provider Switching System

### 8.1 Config Files Per Tool

| Tool | Config File(s) | Format |
|------|---------------|--------|
| **pi** | `~/.pi/agent/settings.json` | JSON — `defaultProvider`, `defaultModel`, `enabledModels` |
| | `~/.pi/agent/auth.json` | JSON — `{ "<provider>": { "type": "api_key", "key": "..." } }` |
| | `~/.pi/agent/models.json` | JSON — `providers.<name>.baseUrl`, `.apiKey`, `.models[]` |

**pi-ai monkey patch required**: When using DeepSeek V4 Pro (or any model with `thinkingFormat: "deepseek"`) through the pi coding agent, a monkey patch is needed in `@earendil-works/pi-ai`. See [Section 8.3](#83-known-pi-ai-monkey-patch-deepseek-v4-pro-reasoning_content).
| **codex** | `~/.codex/config.toml` | TOML — `model`, `[model_providers.<name>]` |
| **mini** | `~/.config/mini-swe-agent/.env` | ENV — `OPENAI_API_BASE`, `OPENAI_API_KEY`, `MSWEA_MODEL_NAME` |
| **qwen** | `~/.qwen/settings.json` | JSON — `model.name`, `security.auth.selectedType`, `modelProviders.openai[]` |
| **claude** | `~/.claude/settings.json` | JSON — `env.ANTHROPIC_AUTH_TOKEN`, `env.ANTHROPIC_BASE_URL`, `env.ANTHROPIC_DEFAULT_*_MODEL` |

**Claude Code routing note**: Claude Code speaks Anthropic protocol exclusively. To route through non-Anthropic providers, set `ANTHROPIC_BASE_URL` to a provider's Anthropic-compatible endpoint (e.g., zenmux's `/api/anthropic`). This requires `CLAUDE_EFFORT=off` because Anthropic's extended thinking produces signed thinking blocks that non-Anthropic backends reject. See Section 8.4.

### 8.2 Config Restore Guarantee

On every exit (normal, Ctrl+C, error), the EXIT trap:
1. Iterates `_AINISH_SWAPPED_TOOLS[]`
2. For each tool, runs the corresponding `_ainish_restore_<tool>()` function
3. Moves the `.ainish-backup` file back to the original config path
4. Clears the tracking array

The interactive CLI (`--cli`) pre-sets `_AINISH_TRAP_SET=1` so `hot_swap.sh` never replaces the trap. Instead, `_cli_cleanup()` calls `_ainish_restore_all` (if it exists) followed by `stty sane`, ensuring both config restore and terminal cleanup execute in the correct order.

### 8.3 Known Monkey Patches (reasoning_content empty-string bug)

DeepSeek V4 Pro (and other DeepSeek-family models in thinking mode) requires `reasoning_content` to be echoed back on every assistant tool-call message. When a model hasn't produced reasoning, these tools set `reasoning_content: ""` (empty string), but DeepSeek's API rejects empty strings with HTTP 400:

```
Error: 400 The reasoning_content in the thinking mode must be passed back to the API.
```

The fix is the same pattern everywhere: change `""` to `" "` (single space).

#### 8.3.1 pi-ai (`@earendil-works/pi-ai`)

**Patched**: 2026-05-23

**File**: `<npm-global>/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/providers/openai-completions.js` line 722

```js
// BEFORE (broken):
assistantMsg.reasoning_content = "";

// AFTER (fixed):
assistantMsg.reasoning_content = " ";
```

**Re-application required after**: `npm update -g @earendil-works/pi-coding-agent`

**Detection**: `model.compat.requiresReasoningContentOnAssistantMessages` is `true` for all `deepseek/deepseek-v4-*` models. Auto-detection also sets it when `provider === "deepseek"` or `baseUrl.includes("deepseek.com")`.

#### 8.3.2 qwen-code (`@qwen-code/qwen-code`)

**Patched**: 2026-05-24

**File**: `<npm-global>/lib/node_modules/@qwen-code/qwen-code/chunks/chunk-N6GSJHZ4.js` line 7333

```js
// BEFORE (broken — ensureReasoningContentOnAssistantMessage):
return {
    ...assistant,
    reasoning_content: ""
};

// AFTER (fixed):
return {
    ...assistant,
    reasoning_content: " "
};
```

**Re-application required after**: `npm update -g @qwen-code/qwen-code`

**Detection**: `isDeepSeekProvider()` in the same file returns true when the model name contains "deepseek", which activates the `DeepSeekOpenAICompatibleProvider` class that calls `ensureReasoningContentOnAssistantMessage`.

#### 8.3.3 Tools NOT affected

| Tool | Why |
|------|-----|
| **mini-swe-agent** | Uses `litellm` internally — handles reasoning_content echo-back correctly |
| **codex (OpenAI)** | Uses OpenAI's Responses API, not Chat Completions — different protocol |
| **hermes-agent** | Already has the fix in `agent_runtime_helpers.py::copy_reasoning_content_for_api` (commit `bfb704684`) |

### 8.4 Known: Claude Code Thinking Disabled (signed thinking blocks)

**Patched**: 2026-05-24

Claude Code (`~/.claude/settings.json`) is routed through zenmux's Anthropic-compatible endpoint (`https://zenmux.ai/api/anthropic`) with `ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek/deepseek-v4-pro`. When `CLAUDE_EFFORT=high`, Claude Code sends Anthropic-proprietary signed thinking blocks. Zenmux proxies these to DeepSeek, which cannot validate the Anthropic signatures and rejects them:

```
API Error: 400 messages.1.content.0: Invalid 'signature' in 'thinking' block
```

**Fix**: `CLAUDE_EFFORT=off` in `~/.claude/settings.json` env vars. This disables extended thinking, preventing signed thinking blocks from being sent.

**Trade-off**: Thinking/reasoning is disabled when using Claude Code through zenmux. For full Anthropic Claude with thinking, use a real Anthropic API key directly.

### 8.5 Single-Source Model Configuration (Design Decision)

`providers.json` is the single source of truth for all provider credentials and models. The hot-swap functions in `bin/lib/hot_swap.sh` read from this one file and translate into each tool's config format.

**Current model name translations** (implicit in hot-swap functions):

| Tool | Translation | Example |
|------|------------|---------|
| **pi** | Strips provider prefix for `defaultModel`; uses `provider/model` in `enabledModels` | `deepseek/deepseek-v4-pro` → `defaultModel: "deepseek-v4-pro"` |
| **mini** | Prepends `openai/` | `deepseek/deepseek-v4-pro` → `MSWEA_MODEL_NAME='openai/deepseek/deepseek-v4-pro'` |
| **qwen** | Passes through as-is | `deepseek/deepseek-v4-pro` → `model.name: "deepseek/deepseek-v4-pro"` |
| **codex** | Passes through as-is | `deepseek/deepseek-v4-pro` → `model = "deepseek/deepseek-v4-pro"` |
| **claude** | Passes through via env var | `deepseek/deepseek-v4-pro` → `ANTHROPIC_DEFAULT_OPUS_MODEL` |

**Next iteration** (planned v1.3): Make these translations explicit via `modelAliases.<tool>` in each provider entry in `providers.json`. This eliminates hidden logic in hot-swap functions and lets users configure per-tool model names directly in one file.

**Provider-separated configs**: When a provider offers multiple authentication contexts (e.g., Wafer subscription vs. API balance), create separate provider entries (`wafer` and `wafer-balance`) with distinct keys, models, and notes. This keeps the single-source pattern intact while supporting multiple accounts per vendor.

---

## 9. Interactive CLI (`--cli`)

### 9.1 Entry Point

```bash
ainish-coder --cli
```

### 9.2 Pre-Flight

- Checks `~/.config/ainish-coder/providers.json` exists
- If missing: prints an example JSON template and exits with code 1
- Registers `_cli_cleanup` as EXIT trap (config restore + `stty sane`)
- Pre-sets `_AINISH_TRAP_SET=1` to prevent `hot_swap.sh` from clobbering the trap

### 9.3 Main Menu Options

| # | Option | Action |
|---|--------|--------|
| 1 | Pick a tool, hot-swap to a provider, and optionally launch it | Tool → Provider → Verify → Swap → Launch flow |
| 2 | Verify config files for a tool | Checks all required config files exist for one or all tools |
| 3 | Show provider ↔ tool compatibility matrix | Live matrix from `providers.json` `tools.<name>` fields |
| 4 | View a provider's details | Base URL, default model, env key, supported tools, config files modified |
| 5 | Exit | Returns to shell; EXIT trap restores all configs |

### 9.4 Input Handling

- Uses `read -re` for readline support (arrow keys, backspace work naturally)
- ANSI escape sequences (from arrow keys pressed before input) are stripped via `sed`
- Empty/invalid input shows a brief guidance message and re-displays the menu
- Every picker supports `q` to go back/quit without making changes
- `Ctrl+C` at any point triggers the EXIT trap → configs restored → clean exit

### 9.5 Hot-Swap Flow (Option 1)

1. Pick tool (pi / codex / mini / qwen) from numbered menu
2. Pick provider (filtered to only compatibly providers for that tool)
3. Confirm screen shows tool, provider, base URL, model
4. User chooses: `Y` (swap + launch), `n` (swap only, no launch), `q` (cancel, nothing changed)
5. On `Y`: optionally enter extra CLI args, then tool is launched
6. Config backup message displayed: "Your original config has been backed up. It will be restored when you exit ainish-coder --cli."

### 9.6 Verify Flow (Option 2)

- Pick a specific tool or "all"
- For each tool, checks every config file path exists
- Also checks `providers.json` exists and lists configured providers with models
- Missing files shown in red with guidance to run the tool once to bootstrap

---

## 10. Skills System

### 10.1 Overview

18 versioned skill packs live in `.agents/skills/<name>/SKILL.md`. Each is a self-contained Markdown file with YAML frontmatter (`name`, `description`, `version`) and instructional body. Skills are deployed via `ainish-coder --skills [DIR]` and loaded on demand by AI coding agents.

### 10.2 Complete Skill Inventory

| # | Skill | Category | Description |
|---|-------|----------|-------------|
| 1 | `advisory-council` | Orchestration | Multi-expert advisory council dispatching sub-agents with distinct expert identities |
| 2 | `anishinaabe-cyberpunk-style` | Aesthetic | Anishinaabe-inspired cyberpunk styling combining Canadian Aboriginal Syllabics with ASCII circuit symbols |
| 3 | `browser-harness` | Automation | Direct browser control via CDP for scraping, testing, and web interaction |
| 4 | `camofox-stack` | Automation | Anti-detection browser stack (camoufox, camofox-browser, camofox-mcp) for agentic scraping |
| 5 | `code-security` | Security | Safety-critical code engineering: SQLi, XSS, CSRF, SSRF, path traversal, MCP hardening |
| 6 | `ghost-layer-injector` | Stealth | Injects covert AI/bot context into static HTML pages via invisible metadata |
| 7 | `gstack-coder` | Coding | Multi-tool coding orchestration integrating gstack (Claude Code skills), pi, opencode, qwen |
| 8 | `llm-security` | Security | LLM & agentic AI security: prompt injection defense, RAG hygiene, PII redaction, MCP allowlisting |
| 9 | `modern-prompting` | Prompt Engineering | OOReDAct, Chain-of-Thought, Chain-of-Draft, ReAct, and advanced LLM steering techniques |
| 10 | `omni-integrator` | Pipeline | Master recursive optimization pipeline and Omni multimodal integration |
| 11 | `omni-knowledge-extractor` | Extraction | YouTube knowledge extraction combining transcripts with sequential visual frames via Omni VLM |
| 12 | `openscad-generator` | 3D Modeling | Parameterized 3D model generation via Python templates + OpenSCAD, compiled to STL |
| 13 | `osa` | Orchestration | Multi-agent orchestration: fixed-order rotation across Gemini, Claude, OpenCode, mini, pi, kilo, crush |
| 14 | `pi` | Tool Knowledge | Pi Coding Agent expertise: extensions, themes, multi-agent orchestrations |
| 15 | `pliny-research` | Research | Extracted system prompts, jailbreak techniques, and AI transparency research |
| 16 | `production-security` | Security | Core security policies, Zero Trust, PQC mandates, threat mitigations |
| 17 | `remotion-video` | Creative | Programmatic video creation with Remotion: all APIs, 3D, captions, Lambda rendering |
| 18 | `skyvern` | Automation | AI-powered browser automation (self-hosted): Vision LLM + Playwright hybrid, BYOM support |

---

## 11. OSA Framework

### 11.1 Concept

Orchestrated System of Agents (OSA) coordinates multiple equal CLI coding agents through fixed-order rotation with automatic fallback.

**Agent roster** (ordered): Gemini → Claude → OpenCode → mini → pi → kilo → crush → (wrap)

### 11.2 Modes

| Mode | Description |
|------|-------------|
| **Sequential Dispatch** | Each agent receives one task; next agent picks up the next task |
| **Parallel Dispatch** | Each agent works on a different file/scope in its own git worktree |
| **YOLO Mode** | Auto-approve with `-y` flag; no human-in-the-loop |

### 11.3 Key Properties

- **Fixed-order rotation** — deterministic task distribution across subscriptions
- **Automatic fallback** — if one agent's API is down, the next in rotation takes the task
- **Git worktree isolation** — each parallel agent works in `git worktree add ../task-<scope> agent-<name>`
- **No single point of failure** — all agents are equal peers; any can be removed from rotation

---

## 12. Security Posture

### 12.1 Cryptographic Standards

| When You Need | You Use | Standard |
|---------------|---------|----------|
| Key exchange | ML-KEM-768 | FIPS 203 |
| Signing | ML-DSA-65 | FIPS 204 |
| High-security KEX | ML-KEM-1024 | FIPS 203 (Level 5) |
| High-security sign | ML-DSA-87 | FIPS 204 (Level 5) |
| Firmware signing | SLH-DSA-SHA2-128s | FIPS 205 |
| Bandwidth-limited | FN-DSA-512 | FIPS 206 |
| Migration path | X25519 + ML-KEM-768 | RFC 9794 (Hybrid) |
| Symmetric encryption | AES-256-GCM / ChaCha20-Poly1305 | — |
| Password hashing | Argon2id (t=3, m=65536, p=4, len=32) | — |

### 12.2 Banned (Never Used for New Systems)

RSA, DSA, ECDSA, ECDH, Ed25519 (standalone), MD5, SHA-1, DES, 3DES, Blowfish, AES-CBC

### 12.3 Security Gate Scanner

`bin/security_gate.py` enforces:
- No banned classical crypto patterns
- No unsanitized path usage (must use `safe_path()`)
- No hardcoded secrets
- Skip lines marked `# nosec` or `# no-gate`

### 12.4 Compliance Baseline

| Domain | Standards |
|--------|-----------|
| **Core** | OWASP LLM Top 10 (2025), OWASP Agentic Top 10 (ASI 2026), OWASP Agentic Skills Top 10 (AST10 2026) |
| **Crypto** | FIPS 203, 204, 205, 206; RFC 9794; AES-256-GCM; TLS 1.3+ |
| **Secrets** | Env-only; never in repo; never in config files; injected at runtime |
| **MCP** | Allowlisted servers; pinned manifests; drift detection; sandboxed execution |
| **Supply Chain** | SBOMs (CycloneDX/SPDX); SLSA attestations; artifact signing (Sigstore); dependency pinning |

### 12.5 Known MCP CVE Mitigations Tracked

| CVE | Product | Mitigation |
|-----|---------|------------|
| CVE-2025-32711 | M365 Copilot (EchoLeak) | Output sanitization; strip markdown image refs |
| CVE-2025-53773 | GitHub Copilot (Worm) | Instruction hierarchy; treat repo text as untrusted |
| CVE-2025-54135 | Cursor (CurXecute) | Require explicit approval; no auto-start |
| CVE-2025-64660 | GitHub Copilot | Behavioral monitoring; AGENTS.md immutability |
| CVE-2026-30615 | Windsurf | Never let LLM output modify system config |
| CVE-2026-30623 | LiteLLM | Auth required for MCP creation; allowlisted definitions |

---

## 13. Milestones & Roadmap

### 13.1 Completed (v1.0 – v1.2)

| Milestone | Status | Date |
|-----------|--------|------|
| `AGENTS.md` deployment system (`--rules`) | ✅ Done | 2026-Q1 |
| `.gitignore` deployment (`--gitignore`) | ✅ Done | 2026-Q1 |
| `llms.txt` deployment (`--llms-txt`, separate from `--rules`) | ✅ Done | 2026-Q1 |
| 18 skill packs created and deployable | ✅ Done | 2026-Q2 |
| Provider-switching wrapper scripts (pi, codex, mini, qwen) | ✅ Done | 2026-Q2 |
| Hot-swap library (backup/rewrite/restore with EXIT trap) | ✅ Done | 2026-Q2 |
| Interactive CLI (`--cli`) with menu-driven tool+provider selection | ✅ Done | 2026-05-23 |
| Config verification system (check all tool configs exist) | ✅ Done | 2026-05-23 |
| Provider ↔ tool compatibility matrix (live from `providers.json`) | ✅ Done | 2026-05-23 |
| EXIT trap hardening (config restore + `stty sane`, never clobbered) | ✅ Done | 2026-05-23 |
| ANSI escape sequence stripping in CLI input | ✅ Done | 2026-05-23 |
| README.md and `--help` documentation audit (7 gaps closed) | ✅ Done | 2026-05-23 |
| `AGENTS_CODE_SECURITY.md` and `AGENTS_LLM_SECURITY.md` created | ✅ Done | 2026-05-23 |
| `--secure` command operational (deploys both security docs to any project) | ✅ Done | 2026-05-23 |
| PRD.md created | ✅ Done | 2026-05-23 |
| pi-ai reasoning_content monkey patch applied | ✅ Done | 2026-05-23 |
| qwen-code reasoning_content monkey patch applied | ✅ Done | 2026-05-24 |
| Claude Code thinking disabled (signed block workaround) | ✅ Done | 2026-05-24 |
| `providers.json` API key audit (dummy keys → real keys) | ✅ Done | 2026-05-24 |
| mini-swe-agent `.env` API key synced to zenmux | ✅ Done | 2026-05-24 |
| nvidia NIM default model → `deepseek/deepseek-v4-flash` | ✅ Done | 2026-05-24 |
| Wafer AI dual config (subscription + balance) | ✅ Done | 2026-05-24 |
| Single-source model configuration documented (Section 8.5) | ✅ Done | 2026-05-24 |
| PRD.md updated (v1.2.0 — all agent fixes documented) | ✅ Done | 2026-05-24 |

### 13.2 Planned (v1.3+)

| Milestone | Priority | Notes |
|-----------|----------|-------|
| `modelAliases` explicit per-tool model names in `providers.json` | High | Replace implicit hot-swap translations with explicit per-tool model name fields |
| `providers.json` live-editing from CLI (`--cli` option 6) | High | Add/edit/remove provider entries from the menu without leaving the CLI |
| Token balance tracking integration | Medium | Poll provider billing endpoints for remaining credits; display in provider details and compatibility matrix |
| `ainish-coder --update` | Medium | Self-update mechanism (git pull + re-source) |
| Non-interactive hot-swap from CLI (`ainish-coder --cli --swap pi openrouter`) | Medium | Skip menu, do the swap and exit immediately |
| Tab completion for bash/zsh | Low | `complete -F _ainish_completion ainish-coder` and per-wrapper completions |
| `providers.json` JSON Schema validation | Low | Schema + validate before reading to catch config errors early |
| Windows native support (PowerShell wrapper) | Low | Currently supported via Git Bash / WSL2 |

### 13.3 Deferred (Handled Elsewhere)

| Feature | Handled By | Notes |
|---------|------------|-------|
| Multi-provider round-robin dispatch | `gstack-coder` skill | `.agents/skills/gstack-coder/SKILL.md` provides fixed-order rotation across providers via OSA framework |
| System health checks ("doctor") | Out of scope | Binary presence and config validity are checked at hot-swap time; reachability is a provider concern |
| Project init wizards | Out of scope | `--rules`, `--skills`, and `--llms-txt` provide one-command setup; no wizard needed |

### 13.4 Backlog (Unprioritized)

- Docker image for CI/CD integration (`ainish-coder` as a GitHub Actions step)
- Web dashboard for provider management (read-only view of `providers.json`)
- Slack/Discord bot that accepts `ainish-coder` commands
- WASM sandboxing for untrusted skill execution
- OIDC-based provider auth (replace static API keys)

---

## 14. Success Criteria

| # | Criterion | Measurement |
|---|-----------|-------------|
| SC1 | New project setup takes ≤ 3 commands | `ainish-coder --rules` + `--llms-txt` + `--skills` |
| SC2 | Provider switch takes ≤ 10 seconds from menu open to tool launched | `--cli` hot-swap flow |
| SC3 | 100% config restore on exit | Zero user reports of corrupted default configs |
| SC4 | 0 hardcoded secrets in the repo | `security_gate.py` passes; `detect-secrets` scan clean |
| SC5 | All 18 skills deploy correctly to any writable directory | `--skills` integration test |
| SC6 | CLI works without internet access | No outbound network calls from the tool itself |
| SC7 | Documentation matches code behavior exactly | 0 stale references found in audit |
| SC8 | Arrow keys and invalid input never break the CLI menu | Escape sequence stripping + retry loop tested |

---

## 15. Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| `hot_swap.sh` EXIT trap clobbered by another trap | High | Pre-set `_AINISH_TRAP_SET=1` in CLI; `_cli_cleanup` calls `_ainish_restore_all` |
| User Ctrl+C during hot-swap leaves configs modified | High | EXIT trap fires on SIGINT; `.ainish-backup` always restored |
| `providers.json` contains invalid JSON | Medium | CLI prints clear error + example; Python `json.load` catches parse errors |
| Tool binary not on PATH | Medium | Clear error message; wrapper falls through to passthrough mode |
| BSD sed vs GNU sed incompatibility | Low | ESC character injected via `$'\033'` bash variable, not `\x1b` in sed |
| Bash version < 4.0 | Low | Documented requirement; macOS ships Bash 3.2 but users can install 5.x |
| Skill pack drift (source ≠ deployed) | Low | `--skills` copies from repo; version bumps track changes |

---

## 16. Glossary

| Term | Definition |
|------|------------|
| **AGENTS.md** | Universal AI agent instruction standard deployed to project root |
| **Atom** | Smallest reusable utility function (colors, paths, validation) |
| **Molecule** | Single-purpose deployment function (one per CLI command) |
| **Protein** | Higher-level orchestration script |
| **Hot-swap** | Temporarily rewrite a tool's config to point to a different API provider |
| **Provider** | An API gateway or model host (OpenRouter, ZenMux, ZAI, NVIDIA, Wafer, Wafer-Balance, OpenCode, Kimi) |
| **OSA** | Orchestrated System of Agents — fixed-order rotation across equal CLI coding agents |
| **YOLO mode** | Auto-approve agent execution with no human-in-the-loop |
| **PQC** | Post-Quantum Cryptography — algorithms resistant to quantum computer attacks |
| **MCP** | Model Context Protocol — server specification for tool-augmented LLMs |
| **8th Fire** | Indigenous prophecy and mission for digital sovereignty and AI survival |
| **Ghost Layer** | Invisible metadata embedded in static content for AI agent ingestion |
| **Plinian Defense** | Prompt engineering techniques that bypass restrictive AI guardrails |
| **EXIT trap** | Bash mechanism (`trap ... EXIT`) that guarantees cleanup code runs on any exit path |

---

*This PRD is a living document. Submit revisions via PR or open an issue at the repo.*

---

## Appendix A: Where to Continue (Next Session)

When starting a new chat with this repo, here is what is verified and what needs testing:

### Verified (no rework needed)

- **pi-ai reasoning_content monkey patch applied** (2026-05-23) — `openai-completions.js:722` changed `""` → `" "`. See Section 8.3.1. **Must re-apply after `npm update`**.
- **qwen-code reasoning_content monkey patch applied** (2026-05-24) — `chunk-N6GSJHZ4.js:7333` changed `""` → `" "`. See Section 8.3.2. **Must re-apply after `npm update`**.
- **Claude Code thinking disabled** (2026-05-24) — `CLAUDE_EFFORT=off` in `~/.claude/settings.json` to avoid signed thinking block rejection. See Section 8.4.
- **providers.json API keys** — nvidia, wafer, opencode dummy keys replaced with real keys from `~/.pi/agent/auth.json`. openrouter and zai keys differ between files (both look real, one might be stale).
- **Nvidia NIM default model** — changed to `deepseek/deepseek-v4-flash` in providers.json.
- **Wafer AI dual config** — `wafer` (subscription key, GLM-5.1) and `wafer-balance` (API balance key, deepseek-v4-flash). The `wafer-balance` key is placeholder — needs real key.
- **mini-swe-agent .env** — API key synced to zenmux `sk-ss-v1-...`.
- Provider library — all functions tested with mock data
- CLI helper functions — all output correctly
- Hot-swap source chain — all 5 hot-swap functions resolve
- `_AINISH_TRAP_SET=1` guard — prevents trap clobbering
- `_cli_read` / `_cli_pick` — ANSI stripping, retry loop, `q` quit
- `--secure` deploys both security docs; `--rules` deploys only AGENTS.md + .gitignore
- All bash files pass syntax check
- PRD.md v1.2.0 — all agent fixes, monkey patches, and architecture decisions documented

### Re-apply After npm Updates

These patches live in dist files that get replaced on `npm update`. Re-apply after any global npm update:

| Package | File | Line | Change |
|---------|------|------|--------|
| `@earendil-works/pi-ai` | `dist/providers/openai-completions.js` | ~722 | `""` → `" "` |
| `@qwen-code/qwen-code` | `chunks/chunk-N6GSJHZ4.js` | ~7333 | `""` → `" "` |

### Needs Interactive Testing (real terminal)

1. Run `ainish-coder --cli` with the updated `providers.json`:
   - 8 providers listed (including wafer-balance)
   - Compatibility matrix shows wafer-balance column
2. Hot-swap flow for each tool+provider pair
3. Verify flow: check all config paths for selected tool

### Next Priority (from Roadmap)

| Priority | Task |
|----------|------|
| High | `modelAliases` — explicit per-tool model names in `providers.json` |
| High | `providers.json` live-editing from CLI (Option 6) |
| High | `wafer-balance` API key — replace placeholder with real key |
| Medium | Token balance tracking in provider details |
| Medium | `ainish-coder --update` self-update |
| Medium | Non-interactive swap: `ainish-coder --cli --swap pi openrouter` |

### Key Files

| File | Role |
|------|------|
| `bin/ainish-coder` | Main entry — sources atoms + molecules, routes commands |
| `dna/molecules/cli_interface.sh` | All CLI menu logic, pickers, hot-swap executor |
| `bin/lib/providers.sh` | Provider JSON reader |
| `bin/lib/hot_swap.sh` | Config backup/rewrite/restore + EXIT trap |
| `bin/{pi,codex,mini,qwen}` | Standalone provider-switching wrappers |
| `~/.config/ainish-coder/providers.json` | Single source of truth — all 8 provider configs |
| `~/.pi/agent/auth.json` | pi agent API key store (sync provider keys here) |
| `~/.claude/settings.json` | Claude Code env vars + model routing |
| `PRD.md` | This document — full spec and roadmap |
| `README.md` | User-facing docs |
| `AGENTS.md` | Universal agent instructions deployed by `--rules` |
