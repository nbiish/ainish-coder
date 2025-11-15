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
- **📘 OSA Orchestrator Patterns**: Distribute execution patterns and agent mappings

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
ainish-coder --rules                     # Deploy AGENTS.md, MAIRULES.md, critical.md, .gitignore, and llms.txt

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
ainish-coder --osa                       # Distribute OSA.md orchestration guide to target
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
ainish-coder --rules                     # Deploys AGENTS.md, MAIRULES.md, critical.md, .gitignore, and llms.txt

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
- Deploys `llms.txt` - Reference list of LLMs used
- Both files are created in the target directory

**Individual Files** (`--agents` or `--mairules`):
- Deploy files individually if you only need one

**Orchestrator Guide** (`--osa`):
- Copies `OSA.md` (execution patterns and agent tool mappings) to the target directory
- Use for orchestrator and sub-agent workflows

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

### Orchestrator Patterns (OSA)

Use `ainish-coder --osa` to distribute `OSA.md` to your project root. This guide covers execution patterns (Sequential, Parallel, Pipeline, Feedback Loop), compile prompt schema, and agent tool mappings to coordinate orchestrator and sub-agent workflows.

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

Generated: 2025-11-08

Command run: `eza --all --tree --level=2`

```text
.
├── .clinerules
├── .configs
│   ├── .claude
│   ├── .clinerules
│   ├── .continue
│   ├── .cursor
│   ├── .gemini
│   ├── .goose
│   ├── .mai-rules
│   ├── .qwen
│   ├── .roo
│   ├── .trae
│   ├── .windsurf
│   └── MCP
├── .continue
│   ├── prompts
│   └── rules
├── .copilotignore
├── .copilotindexignore
├── .cursor
│   ├── commands
│   └── rules
├── .cursorignore
├── .cursorindexignore
├── .DS_Store
├── .gemini
│   ├── AGENTS.md
│   ├── commands
│   └── MAIRULES.md
├── .git
│   ├── COMMIT_EDITMSG
│   ├── config
│   ├── cursor_metadata.pb
│   ├── description
│   ├── FETCH_HEAD
│   ├── HEAD
│   ├── hooks
│   ├── index
│   ├── info
│   ├── logs
│   ├── objects
│   ├── ORIG_HEAD
│   ├── packed-refs
│   └── refs
├── .git-secrets-setup.sh
├── .github
│   ├── copilot-instructions.md
│   ├── FUNDING.yml
│   ├── prompts
│   └── workflows
├── .gitignore
├── .goose
│   ├── AGENTS.md
│   ├── MAIRULES.md
│   └── recipes
├── .windsurf
│   ├── rules
│   └── workflows
├── AGENTS.md
├── bin
│   ├── ainish-coder
│   ├── ainish-coder.bak
│   └── README.md
├── buymeacoffee-button.svg
├── CHECKLIST.md
├── CONTRIBUTING.md
├── critical.md
├── dna
│   ├── atoms
│   ├── molecules
│   ├── proteins
│   └── README.md
├── fix-path.sh
├── GITHUB_ACTIONS_SETUP.md
├── knowledge-base
│   ├── CLINE_RULES_SYSTEM.md
│   ├── COMPREHENSIVE_DEPLOYMENT_UPDATE.md
│   ├── DEVELOPMENT.md
│   ├── IMPLEMENTATION_VERIFICATION_REPORT.md
│   ├── OSAA_FRAMEWORK.md
│   ├── OSAA_IMPLEMENTATION.md
│   ├── SECRET_PROTECTION_SETUP.md
│   ├── SLASH_COMMANDS_CORRECTIONS.md
│   ├── SLASH_COMMANDS_DEPLOYMENT.md
│   ├── TEMPLATE_AGENT_IMPLEMENTATION.md
│   ├── TEMPLATE_AGENT_SYSTEM.md
│   ├── TEST_RESULTS.md
│   ├── TODO.md
│   ├── TRAE_INTEGRATION.md
│   ├── TRAE_QUICK_REFERENCE.md
│   ├── TRAE_RESEARCH_SOURCES.md
│   ├── TRAE_RULES_VERIFICATION.md
│   └── VSCODE_COPILOT_DEPLOYMENT.md
├── LICENSE
├── MAIRULES.md
├── OSAA.md
├── Privacy-Policy.md
├── qr-stripe-donation.png
├── README.md
├── Terms-of-Service.md
├── TIER_0_RULES
│   └── docs-protocol.md
├── TIER_1_RULES
│   └── uv-python.md
├── TIER_2_RULES
│   ├── code-security.md
│   └── prompt-security.md
├── TIER_3_RULES
│   └── anishinaabe-cyberpunk-style.md
└── TIER_4_RULES
    └── modern-prompting.md
```
