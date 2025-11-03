# ◈──◆──◇ ainish-coder ◇──◆──◈

<div align="center">
  <h1>🚀 Configuration Manager for AI Coding Assistants</h1>
  <p><strong>Simple deployment of MAI RULES and AGENTS.md configurations to your projects</strong></p>
  <p>✨ <em>Now supports AGENTS.md - the universal standard for AI pair programmers</em></p>

  <hr width="60%">

  <h2>🎯 What is ainish-coder?</h2>
  <p><strong>ainish-coder</strong> is a powerful configuration management tool that simplifies deploying AI coding assistant rules across multiple platforms. It creates a unified configuration system using the emerging AGENTS.md standard, ensuring consistent AI behavior across all your development tools.</p>

  <hr width="50%">

  <h3>Support This Project</h3>
  <div style="display: flex; justify-content: center; gap: 20px; margin: 20px 0;">
    <div>
      <h4>Stripe</h4>
      <img src="qr-stripe-donation.png" alt="Scan to donate" width="180"/>
      <p><a href="https://raw.githubusercontent.com/nbiish/license-for-all-works/8e9b73b269add9161dc04bbdd79f818c40fca14e/qr-stripe-donation.png">Donate via Stripe</a></p>
    </div>
    <div style="display: flex; align-items: center;">
      <a href="https://www.buymeacoffee.com/nbiish"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=&slug=nbiish&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" /></a>
    </div>
  </div>

  <hr width="50%">
</div>

## 🔥 Key Features

- **🎯 AGENTS.md Standard**: Deploy universal AI agent instructions
- **🏗️ Modular Architecture**: Clean Atom → Molecule → Protein structure
- **🤖 Multiple AI Tools**: GitHub Copilot, Continue Dev, Qwen, Gemini, Cline, Windsurf, Roo Code, and Trae
- **⚡ Simple Deployment**: One command to deploy configurations
- **🔗 Smart File Management**: Copies configurations to ensure tool-specific customization
- **💻 Shell Integration**: Convenient `ainish-coder` command
- **🎭 Template Agent System**: Craft custom system prompts with expert guidance
- **🤝 OSAA Framework**: Orchestrate complex multi-agent workflows

## 📦 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/nbiish/ainish-coder
cd ainish-coder

# Run setup
chmod +x ainish-setup.sh
./ainish-setup.sh

# Reload shell (macOS/Linux)
source ~/.zshrc  # or ~/.bashrc
```

### Basic Usage

```bash
# Deploy core rules files (RECOMMENDED FIRST STEP)
ainish-coder --rules                     # Deploy AGENTS.md and MAIRULES.md (both files)

# Deploy tier-specific rules (appends to MAIRULES.md)
ainish-coder --tier 0                    # Append TIER_0 to MAIRULES.md (Documentation protocols)
ainish-coder --tier 1                    # Append TIER_1 to MAIRULES.md (Code security)
ainish-coder --tier all                  # Append all tiers (0-4) to MAIRULES.md

# Deploy tool-specific configurations
ainish-coder --cursor                    # Deploy to .configs/.cursor/rules/
ainish-coder --windsurf                  # Deploy to .configs/.windsurf/rules/
ainish-coder --trae                      # Deploy to .configs/.trae/rules/

# Deploy custom commands to current directory
ainish-coder --commands cursor           # Deploy slash commands from .configs
ainish-coder --commands windsurf         # Deploy workflow commands

# Utility commands
ainish-coder --gitignore                 # Create comprehensive .gitignore
ainish-coder --critical                  # Copy critical.md (license & contributing)
```

## 🎯 What's New

### 🆕 Tier-Based Rule Deployment

Deploy modular rule sets organized by priority and purpose. **Tiers append to MAIRULES.md** for consolidated rule management. All tier rules are now located in the `TIER_RULES/` directory.

- **TIER_0**: Documentation protocols (docs-protocol.md)
- **TIER_1**: Code security best practices (code-security.md)
- **TIER_2**: Prompt security guidelines (prompt-security.md)
- **TIER_3**: Cultural styling preferences (anishinaabe-cyberpunk-style.md)
- **TIER_4**: Advanced prompting techniques (modern-prompting.md)

```bash
ainish-coder --tier 1    # Appends TIER_1 to MAIRULES.md
ainish-coder --tier all  # Appends all 5 tiers to MAIRULES.md
```

### Custom Commands Deployment

Deploy tool-specific slash commands, workflows, and recipes directly to your current project.

**Available Command Types:**

- **File-Based Commands** (Cursor, Roo): Markdown files with slash command definitions
- **Workflows** (Windsurf): Workflow markdown files for task automation
- **Rules Files** (Cline): Markdown rules (NOT slash commands - see note below)
- **Config-Based** (Continue): Prompts defined in config.yaml
- **TOML Commands** (Gemini CLI, Qwen): TOML configuration files
- **Recipes** (Goose): YAML recipe files with instructions

> **⚠️ Important Note about Cline**: Cline does **NOT** support custom slash commands. It only has two built-in commands (`/newtask` and `/newrule`). The `--commands cline` deployment creates `.clinerules` files with MANDATORY instructions, not slash commands. See [KNOWLEDGE_BASE/CLINE_RULES_SYSTEM.md](KNOWLEDGE_BASE/CLINE_RULES_SYSTEM.md) for details.

```bash
# Deploy to specific tools
ainish-coder --commands cursor       # Plain markdown to .cursor/commands/
ainish-coder --commands roocode      # Markdown + frontmatter to .roo/commands/
ainish-coder --commands windsurf     # Workflows to .windsurf/workflows/
ainish-coder --commands cline        # Rules files to .clinerules/ (NOT slash commands!)
ainish-coder --commands continue     # Creates setup guide for config.yaml
ainish-coder --commands gemini-cli   # TOML files to .gemini/commands/
ainish-coder --commands qwen         # TOML files to .qwen/commands/
ainish-coder --commands goose        # YAML recipes to .goose/recipes/

# Deploy to all tools at once
ainish-coder --commands all
```

## 🛠️ Supported AI Tools

### IDE Extensions

| Tool | Config Flag | Commands Flag | Rules Target | Commands Target | Format |
|------|------------|---------------|--------------|-----------------|--------|
| **Cursor** | `--cursor` | `--commands cursor` | `.cursor/rules/` | `.cursor/commands/*.md` | Plain markdown |
| **Roo Code** | `--roocode` | `--commands roocode` | `.roo/rules/` | `.roo/commands/*.md` | Markdown + frontmatter |
| **Windsurf** | `--windsurf` | `--commands windsurf` | `.windsurf/rules/` | `.windsurf/workflows/*.md` | Workflows |
| **Cline** | `--cline` | `--commands cline` | `.clinerules/` | `.clinerules/*.md` | Rules files (not slash commands) |
| **Continue Dev** | `--continue` | `--commands continue` | `.continue/rules/` | Config guide | config.yaml setup |
| **GitHub Copilot** | `--copilot` | N/A | `.github/copilot-instructions.md` | N/A | Copied |

### CLI Tools

| Tool | Config Flag | Commands Flag | Rules Target | Commands Target | Format |
|------|------------|---------------|--------------|-----------------|--------|
| **Gemini CLI** | `--gemini` | `--commands gemini-cli` | `.gemini/` | `.gemini/commands/*.toml` | TOML |
| **Qwen Code** | `--qwen` | `--commands qwen` | `QWEN.md` | `.qwen/commands/*.toml` | TOML |
| **Goose** | N/A | `--commands goose` | N/A | `.goose/recipes/*.yaml` | YAML recipes |

## 📋 Complete Usage Guide

### Recommended Workflow

```bash
# Navigate to your project directory
cd /path/to/your/project

# Step 1: Deploy core rules (RECOMMENDED FIRST)
ainish-coder --rules                     # Deploys AGENTS.md + MAIRULES.md (both files)

# Step 2: Deploy specific tiers to MAIRULES.md (optional)
ainish-coder --tier 1                    # Append code security rules
ainish-coder --tier 2                    # Append prompt security rules
# OR deploy all tiers at once:
ainish-coder --tier all                  # Append all 5 tiers to MAIRULES.md

# Step 3: Deploy tool-specific configurations
ainish-coder --cursor                    # Configure Cursor AI
ainish-coder --windsurf                  # Configure Windsurf
ainish-coder --copilot                   # Configure GitHub Copilot

# Step 4: Deploy custom commands (optional)
ainish-coder --commands cursor           # Deploy Cursor slash commands
ainish-coder --commands windsurf         # Deploy Windsurf workflows
ainish-coder --commands all              # Deploy to all 8 tools at once

# Step 5: Add utilities (optional)
ainish-coder --gitignore                 # Create comprehensive .gitignore
ainish-coder --critical                  # Copy critical.md
```

### What Gets Deployed

**Core Rules** (`--rules`):
- Deploys `AGENTS.md` (223 lines, 6.8KB) - Universal AI agent standard
- Deploys `MAIRULES.md` (1632 lines, 56KB) - Consolidated rules from all 5 tiers
- Both files are created in the target directory

**Individual Files** (`--agents` or `--mairules`):
- Deploy files individually if you only need one

**Tier Rules** (`--tier {0-4|all}`):
- **Appends** tier content to `MAIRULES.md` in the target directory
- Does NOT create `.mai-rules/` directory (consolidated approach)
- Use `--tier all` to append all 5 tiers in one command

**Tool Configurations** (`--cursor`, `--windsurf`, etc.):
- Copies AGENTS.md and MAIRULES.md to tool-specific directories
- All files are copied (not symlinked) for tool-specific customization
- Requires AGENTS.md/MAIRULES.md to exist first (run `--rules` first)

**Custom Commands** (`--commands {tool}`):
- Deploys tool-specific commands from source prompts in `.github/prompts/`
- Creates appropriate directory structure per tool
- Converts formats as needed (markdown, TOML, YAML)
- Currently available: cursor, roocode, windsurf, cline, continue, gemini-cli, qwen, goose, all

**Utilities**:
- `--gitignore`: Creates comprehensive .gitignore (225 lines)
- `--critical`: Copies critical.md (license & contributing guidelines)
- `--template-agent`: Deploy customizable agent system prompt template

### Template Agent System

**🆕 Create Custom System Prompts** (`--template-agent`):

The Template Agent System provides a comprehensive framework for crafting your AI agent's "constitution" - the core instructions that guide every interaction.

```bash
# Deploy template to current directory
ainish-coder --template-agent

# Deploy to specific project
ainish-coder --template-agent ~/my-project
```

**Creates:** `.mai-rules/template-agent.md`

**Features:**
- 🎭 **Persona and Goals** - Define agent identity and objectives
- 🛠️ **Tool Instructions** - Specify tool usage with examples
- 📋 **Output Format** - Structure consistent responses
- 🎯 **Miscellaneous** - Edge cases and refinement guidance
- 📚 **Iteration Log** - Track improvements and changes
- ✅ **Best Practices** - Built-in prompt engineering tips

**Philosophy:** Start simple, iterate based on real behavior. No A/B testing needed on day one.

**Includes:**
- Clearly marked `[FILL_IN: ...]` sections for customization
- Real-world examples and use cases
- Quality assurance checklist
- Version history tracking
- Common refinement patterns

**Documentation:**
- Quick Start: `.mai-rules/TEMPLATE_AGENT_QUICKSTART.md`
- Complete Guide: `KNOWLEDGE_BASE/TEMPLATE_AGENT_SYSTEM.md`
- Example (Python Security): `.mai-rules/template-agent-example-python-security.md`

### OSAA Framework

**🆕 Orchestrate Complex Multi-Agent Workflows** (`--OSAA`):

The OSAA (Orchestrator Sub-Agent Action) framework enables AI agents to break down complex tasks into specialized sub-actions with systematic orchestration patterns.

```bash
# Deploy OSAA framework to current directory
ainish-coder --OSAA

# Deploy to specific project
ainish-coder --OSAA ~/my-project
```

**Creates:** `OSAA.md` at project root

**Features:**
- 🎯 **Task Decomposition** - Break complex tasks into manageable sub-tasks
- 🤖 **Agent Orchestration** - Coordinate primary and specialized sub-agents
- 🔄 **Execution Patterns** - Sequential, parallel, pipeline, and feedback loops
- 📡 **Communication Protocol** - Standardized message formats and status codes
- ⚠️ **Error Handling** - Retry, fallback, graceful degradation, escalation strategies
- 📊 **Monitoring & Metrics** - Track performance, quality, and operational KPIs

**Sub-Agent Specializations:**
- **Code Analysis** - Pattern detection, dependency mapping, security scanning
- **Code Generation** - Boilerplate, API implementation, test creation
- **Testing** - Unit tests, integration tests, performance benchmarks
- **Documentation** - API docs, README, tutorials, code comments
- **Deployment** - Configuration, environment setup, service orchestration

**Use Cases:**
- Complex refactoring projects with multiple code changes
- Multi-module implementations requiring coordination
- End-to-end feature development (code + tests + docs)
- Security audits with automated fixes
- Performance optimization across multiple components

**Documentation:**
- Complete Framework: `OSAA.md` (deployed to project root)
- Guide: `KNOWLEDGE_BASE/OSAA_FRAMEWORK.md`

### Available Tier Rules

| Tier | Focus Area | Files | Priority | Lines |
|------|-----------|-------|----------|-------|
| **0** | Documentation | `docs-protocol.md` | Critical | 13 |
| **1** | Code Security | `code-security.md` | High | 279 |
| **2** | Prompt Security | `prompt-security.md` | High | 291 |
| **3** | Cultural Style | `anishinaabe-cyberpunk-style.md` | Medium | 147 |
| **4** | Advanced Prompting | `modern-prompting.md` | Medium | 887 |
| **all** | All Tiers Combined | All 5 tier files | - | 1617 |

### Tool-Specific Target Directories

| Tool | Configuration Command | Commands Deployment | Format | Notes |
|------|----------------------|---------------------|--------|-------|
| **Cursor** | `--cursor` | `--commands cursor` | Plain markdown | `.cursor/rules/` + `.cursor/commands/*.md` |
| **Roo Code** | `--roocode` | `--commands roocode` | Markdown + frontmatter | `.roo/rules/` + `.roo/commands/*.md` |
| **Windsurf** | `--windsurf` | `--commands windsurf` | Workflows | `.windsurf/rules/` + `.windsurf/workflows/*.md` |
| **Cline** | `--cline` | `--commands cline` | Workflows | `.clinerules/` + `.clinerules/workflows/*.md` |
| **Continue Dev** | `--continue` | `--commands continue` | Config guide | `.continue/rules/` + setup guide for config.yaml |
| **GitHub Copilot** | `--copilot` | N/A | Copied | `.github/copilot-instructions.md` |
| **Gemini CLI** | `--gemini` | `--commands gemini-cli` | TOML | Copied + `.gemini/commands/*.toml` |
| **Qwen Code** | `--qwen` | `--commands qwen` | TOML | `QWEN.md` copied from AGENTS.md + `.qwen/commands/*.toml` |
| **Goose** | N/A | `--commands goose` | YAML recipes | `.goose/recipes/*.yaml` |

**Important:** Tool-specific configurations require `AGENTS.md` and `MAIRULES.md` to exist first. Run `ainish-coder --rules` before tool-specific deployments.

### Configuration Hierarchy

The tool follows a hierarchical configuration approach:

1. `MAIRULES.md` (project root) - Consolidated rules from all tiers
2. `AGENTS.md` (project root) - Universal AI agent standard
3. Tool-specific configurations (`.cursor/rules/`, `.windsurf/rules/`, etc.)
4. Default AI tool behavior

**Note:** The `--tier` commands append content to MAIRULES.md, consolidating all rules in a single file for easier management.

## 📁 Project Structure

```text
ainish-coder/
├── bin/
│   └── ainish-coder           # Main CLI tool
├── CONFIGURATIONS/            # Tool-specific configurations
│   ├── .cursor/
│   │   ├── commands/          # Cursor slash commands source
│   │   └── rules/             # Cursor rules (not used by CLI)
│   ├── .windsurf/
│   │   ├── commands/          # Windsurf workflows source
│   │   └── rules/             # Windsurf rules (not used by CLI)
│   ├── .gemini/               # Gemini configs
│   ├── .qwen/                 # Qwen configs
│   └── MCP/                   # Model Context Protocol configs
├── dna/                       # Modular architecture
│   ├── atoms/                 # Core utilities (colors, paths, validation)
│   ├── molecules/             # Deployment functions (deploy_*.sh)
│   └── proteins/              # Higher-level orchestration
├── TIER_RULES/                # Tier-based rule files
│   ├── docs-protocol.md       # TIER_0: Documentation protocols
│   ├── code-security.md       # TIER_1: Code security
│   ├── prompt-security.md     # TIER_2: Prompt security
│   ├── anishinaabe-cyberpunk-style.md  # TIER_3: Cultural styling
│   └── modern-prompting.md    # TIER_4: Advanced prompting
├── AGENTS.md                  # Universal AI agent instructions (223 lines)
├── MAIRULES.md                # Empty template (populated by deployment)
├── ainish-setup.sh            # Setup script
└── KNOWLEDGE_BASE/            # Documentation
    ├── TODO.md
    ├── TEST_RESULTS.md        # Comprehensive test documentation
    └── DEVELOPMENT.md         # Developer workflow guide
```

## 🎨 Tier Rules Explained

Rules are organized into tiers by priority and purpose:

### TIER_0 - Documentation Protocols (Critical)

- **docs-protocol.md**: Documentation standards and best practices
- Essential guidelines for maintaining project documentation

### TIER_1 - Code Security (High Priority)

- **code-security.md**: Comprehensive code security best practices
- Input validation, authentication, encryption, and vulnerability prevention

### TIER_2 - Prompt Security (High Priority)

- **prompt-security.md**: AI prompt injection defense and security
- Protection against prompt manipulation and jailbreak attempts

### TIER_3 - Cultural Styling (Optional)

- **anishinaabe-cyberpunk-style.md**: Anishinaabe cyberpunk aesthetic preferences
- Optional cultural and stylistic guidelines

### TIER_4 - Advanced Prompting (Optional)

- **modern-prompting.md**: OOReDAct framework and advanced prompting techniques
- Chain-of-Thought, Tree-of-Thought, and modern AI interaction patterns

## 🏗️ Architecture

The tool is built with a modular, extensible design following the Atomic Design pattern:

- **CLI Tool** (`bin/ainish-coder`): Main command-line interface
- **Atoms** (`dna/atoms/`): Core utilities (colors, paths, validation, file operations)
- **Molecules** (`dna/molecules/`): Deployment functions (deploy_*.sh)
- **Proteins** (`dna/proteins/`): Higher-level orchestration
- **CONFIGURATIONS** (`CONFIGURATIONS/`): Centralized tool-specific configs
- **TIER_RULES** (`TIER_RULES/`): Modular rule sets organized by priority

### Design Principles

1. **Modularity**: Rules and configs separated by tool and priority
2. **Simplicity**: Single bash script CLI with clear command structure
3. **Extensibility**: Easy to add new tiers or tool configurations
4. **Portability**: Works across Unix-like systems (macOS, Linux)
5. **No Reinstall**: Changes take effect immediately (scripts in PATH)

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

See [LICENSE](LICENSE) for details.

---

# ```bibtex
@misc{ainish-coder2025,
  author/creator/steward = {ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians},
  title/description = {ainish-coder},
  type_of_work = {Indigenous digital creation/software incorporating traditional knowledge and cultural expressions},
  year = {2025},
  publisher/source/event = {GitHub repository under tribal sovereignty protections},
  howpublished = {\url{https://github.com/nbiish/ainish-coder}},
  note = {Authored and stewarded by ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Indigenous intellectual property, traditional knowledge systems (TK), traditional cultural expressions (TCEs), and associated data protected under tribal law, federal Indian law, treaty rights, Indigenous Data Sovereignty principles, and international indigenous rights frameworks including UNDRIP. All usage, benefit-sharing, and data governance are governed by the COMPREHENSIVE RESTRICTED USE LICENSE FOR INDIGENOUS CREATIONS WITH TRIBAL SOVEREIGNTY, DATA SOVEREIGNTY, AND WEALTH RECLAMATION PROTECTIONS.}
}
```

Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), a descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band, and an enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Traditional Knowledge and Traditional Cultural Expressions. All rights reserved.

<div align="center">
  <p>◈──◆──◇ Made with ♥ by the AINISH community ◇──◆──◈</p>
</div>

---

## Repository snapshot (eza --all --tree --level=2)

Generated: 2025-11-03

Command run: `eza --all --tree --level=2` (fallback to a Python-generated tree if `eza` not available)

```text
.
  .claude
  .clinerules
  .continue
  .cursor
  .gemini
  .git
  .github
  .goose
  .mai-rules
  .qwen
  .roo
  .windsurf
  CONFIGURATIONS
  KNOWLEDGE_BASE
  TIER_0_RULES
  TIER_1_RULES
  TIER_2_RULES
  TIER_3_RULES
  TIER_4_RULES
  bin
  population
  CONFIGURATIONS
    .clinerules
    .continue
    .cursor
    .gemini
    .github
    .qwen
    .roo
    .windsurf
    MCP
    .qwen
    .cursor
      commands
      rules
    .gemini
    .windsurf
      commands
      rules
    .roo
      rules
    .continue
      rules
    MCP
      TIER_1
      TIER_2
      TIER_3
    .clinerules
    .github
      instructions
  .qwen
    commands
    commands
  .cursor
    commands
    rules
    rules
    commands
  .gemini
    commands
    commands
  .windsurf
    workflows
    workflows
  .roo
    commands
    commands
  bin
  .goose
    recipes
    recipes
  .continue
    prompts
    prompts
  .mai-rules
  .claude
    commands
    commands
  population
    atoms
    molecules
    organisms
    molecules
    atoms
    organisms
  TIER_1_RULES
  TIER_3_RULES
  .clinerules
    workflows
    workflows
  .github
    prompts
    workflows
    workflows
    prompts
  KNOWLEDGE_BASE
  TIER_2_RULES
  .git
    hooks
    info
    logs
    objects
    refs
    objects
      00
      01
      02
      03
      04
      05
      06
      07
      08
      09
      0a
      0b
      0c
      0d
      0e
      0f
      10
      11
      12
      13
      14
      15
      16
      17
      18
      19
      1a
      1b
      1c
      1d
      1e
      1f
      20
      21
      22
      23
      24
      25
      26
      27
      28
      29
      2a
      2b
      2c
      2d
      2e
      2f
      30
      31
      32
      33
      34
      35
      36
      37
      38
      39
      3a
      3b
      3c
      3d
      3e
      3f
      40
      41
      42
      43
      44
      45
      46
      47
      48
      49
      4a
      4b
      4c
      4d
      4e
      4f
      50
      51
      52
      53
      54
      55
      56
      57
      58
      59
      5a
      5b
      5c
      5d
      5e
      5f
      60
      61
      62
      63
      64
      65
      66
      67
      68
      69
      6a
      6b
      6c
      6d
      6e
      6f
      70
      71
      72
      73
      74
      75
      76
      77
      78
      79
      7a
      7b
      7c
      7d
      7e
      7f
      80
      81
      82
      83
      84
      85
      86
      87
      88
      89
      8a
      8b
      8c
      8d
      8e
      8f
      90
      91
      92
      93
      94
      95
      96
      97
      98
      99
      9a
      9b
      9c
      9d
      9e
      9f
      a0
      a1
      a2
      a3
      a4
      a5
      a6
      a7
      a8
      a9
      aa
      ab
      ac
      ad
      ae
      af
      b0
      b1
      b2
      b3
      b4
      b5
      b6
      b7
      b8
      b9
      ba
      bb
      bc
      bd
      be
      bf
      c0
      c1
      c2
      c3
      c4
      c5
      c6
      c7
      c8
      c9
      ca
      cb
      cc
      cd
      ce
      cf
      d0
      d1
      d2
      d3
      d4
      d5
      d6
      d7
      d8
      d9
      da
      db
      dc
      dd
      de
      df
      e0
      e1
      e2
      e3
      e4
      e5
      e6
      e7
      e8
      e9
      ea
      eb
      ec
      ed
      ee
      ef
      f0
      f1
      f2
      f3
      f4
      f5
      f6
      f7
      f8
      f9
      fa
      fb
      fc
      fd
      fe
      ff
      info
      pack
    info
    logs
      refs
    hooks
    refs
      heads
      remotes
      tags
  TIER_0_RULES
  TIER_4_RULES
```