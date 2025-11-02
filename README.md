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
- **🏗️ Modular Architecture**: Clean Atom → Molecule → Matter structure
- **🤖 Multiple AI Tools**: GitHub Copilot, Continue Dev, Qwen, Gemini, Cline, Windsurf, Roo Code
- **⚡ Simple Deployment**: One command to deploy configurations
- **🔗 Smart Symlinks**: Unified configuration across tools
- **💻 Shell Integration**: Convenient `ainish-coder` command

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
# Deploy custom commands to current directory
ainish-coder --commands cursor           # Deploy slash commands to .cursor/commands/
ainish-coder --commands windsurf         # Deploy workflows to .windsurf/workflows/

# Deploy tier-specific rules to current directory (NEW!)
ainish-coder --tier 0                    # Deploy TIER_0_RULES to .mai-rules/
ainish-coder --tier 1                    # Deploy TIER_1_RULES to .mai-rules/
ainish-coder --tier 3                    # Deploy TIER_3_RULES to .mai-rules/
```

## 🎯 What's New

### 🆕 Tier-Based Rule Deployment

Deploy modular rule sets organized by priority and purpose:

- **TIER_0_RULES**: Documentation protocols (docs-protocol.md)
- **TIER_1_RULES**: Code security best practices (code-security.md)
- **TIER_2_RULES**: Prompt security guidelines (prompt-security.md)
- **TIER_3_RULES**: Cultural styling preferences (anishinaabe-cyberpunk-style.md)
- **TIER_4_RULES**: Advanced prompting techniques (modern-prompting.md)

```bash
ainish-coder --tier 1  # Deploys TIER_1_RULES/* to .mai-rules/
```

### Custom Commands Deployment

Deploy tool-specific slash commands and workflows directly from the `CONFIGURATIONS/` directory to your current project.

## 🛠️ Supported AI Tools

| Tool | Commands Flag | Configurations Available |
|------|---------------|--------------------------|
| **Cursor** | `--commands cursor` | ✅ Slash commands in `.cursor/commands/` |
| **Windsurf** | `--commands windsurf` | ✅ Workflows in `.windsurf/commands/` |
| **Continue Dev** | `--commands continue` | ✅ Commands in `.continue/commands/` |
| **Cline** | `--commands cline` | ✅ Commands in `.cline/commands/` |
| **Roo Code** | `--commands roo` | ✅ Commands in `.roo/commands/` |
| **Claude Code** | `--commands claude` | ✅ Commands in `.claude/commands/` |
| **GitHub Copilot** | `--commands copilot` | 📦 Commands structure ready |
| **Gemini** | `--commands gemini` | 📦 Commands structure ready |
| **Qwen AI** | `--commands qwen` | 📦 Commands structure ready |

## 📋 Complete Usage Guide

### Recommended Workflow

```bash
# Navigate to your project directory
cd /path/to/your/project

# Step 1: Deploy tier-specific rules to .mai-rules/
ainish-coder --tier 0                    # Documentation protocols
ainish-coder --tier 1                    # Code security
ainish-coder --tier 2                    # Prompt security
ainish-coder --tier 3                    # Cultural styling (optional)
ainish-coder --tier 4                    # Advanced prompting (optional)

# Step 2: Deploy custom commands for your AI tools
ainish-coder --commands cursor           # Cursor slash commands
ainish-coder --commands windsurf         # Windsurf workflows
ainish-coder --commands roo              # Roo Code commands
ainish-coder --commands claude           # Claude Code commands
ainish-coder --commands cline            # Cline commands
```

### What Gets Deployed

**Tier Rules** (`--tier {0-4}`):

- Deploys markdown files from `TIER_{N}_RULES/` to `.mai-rules/` in current directory
- All tier rules can coexist in `.mai-rules/` for comprehensive coverage
- Rules are automatically recognized by AI tools supporting the MAI RULES standard

**Custom Commands** (`--commands {tool}`):

- Deploys tool-specific commands/workflows from `CONFIGURATIONS/.{tool}/commands/`
- Creates appropriate directory structure (varies by tool)
- Preserves any existing commands in the target directory

### Available Tier Rules

| Tier | Focus Area | Files | Priority |
|------|-----------|-------|----------|
| **0** | Documentation | `docs-protocol.md` | Critical |
| **1** | Code Security | `code-security.md` | High |
| **2** | Prompt Security | `prompt-security.md` | High |
| **3** | Cultural Style | `anishinaabe-cyberpunk-style.md` | Medium |
| **4** | Advanced Prompting | `modern-prompting.md` | Medium |

### Tool-Specific Target Directories

| Tool | Source | Target Directory | Notes |
|------|--------|-----------------|-------|
| **cursor** | `CONFIGURATIONS/.cursor/commands/` | `.cursor/commands/` | Slash commands |
| **continue** | `CONFIGURATIONS/.continue/commands/` | `.continue/commands/` | Custom commands |
| **windsurf** | `CONFIGURATIONS/.windsurf/commands/` | `.windsurf/workflows/` | Workflow files (slash commands) |
| **cline** | `CONFIGURATIONS/.cline/commands/` | `.cline/commands/` | Slash commands |
| **roo** | `CONFIGURATIONS/.roo/commands/` | `.roo/commands/` | Slash commands |
| **claude** | `CONFIGURATIONS/.claude/commands/` | `.claude/commands/` | Claude Code slash commands |
| **copilot** | `CONFIGURATIONS/.copilot/commands/` | `.copilot/commands/` | Custom commands |
| **gemini** | `CONFIGURATIONS/.gemini/commands/` | `.gemini/commands/` | Custom commands |
| **qwen** | `CONFIGURATIONS/.qwen/commands/` | `.qwen/commands/` | Custom commands |

### Configuration Hierarchy

The tool follows a hierarchical configuration approach:

1. `.mai-rules/*.md` (project-specific) - **highest priority**
2. `MAIRULES.md` (project root) - traditional format
3. `AGENTS.md` (project root) - universal AI agent standard
4. Tool-specific configurations
5. Default AI tool behavior

## 📁 Project Structure

```text
ainish-coder/
├── bin/
│   └── ainish-coder           # Main CLI tool
├── CONFIGURATIONS/            # Tool-specific configurations
│   ├── .cursor/
│   │   ├── commands/          # Cursor slash commands
│   │   └── rules/             # Cursor rules
│   ├── .windsurf/
│   │   ├── commands/          # Windsurf workflows source
│   │   └── rules/             # Windsurf rules
│   ├── .continue/
│   │   └── rules/             # Continue Dev rules
│   ├── .cline/                # Cline configurations
│   ├── .roo/                  # Roo Code configurations
│   ├── .github/               # GitHub Copilot configs
│   ├── .gemini/               # Gemini configs
│   ├── .qwen/                 # Qwen configs
│   └── MCP/                   # Model Context Protocol configs
├── TIER_0_RULES/              # Documentation protocols
│   └── docs-protocol.md
├── TIER_1_RULES/              # Code security
│   └── code-security.md
├── TIER_2_RULES/              # Prompt security
│   └── prompt-security.md
├── TIER_3_RULES/              # Cultural styling
│   └── anishinaabe-cyberpunk-style.md
├── TIER_4_RULES/              # Advanced prompting
│   └── modern-prompting.md
├── .mai-rules/
│   └── MAIRULES.md            # Core MAI rules
├── AGENTS.md                  # Universal AI agent instructions
├── MAIRULES.md                # Root-level rules
├── ainish-setup.sh            # Setup script
├── KNOWLEDGE_BASE/            # Documentation
│   └── TODO.md
└── lib/                       # Future modular architecture
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

The tool is built with a modular, extensible design:

- **CLI Tool** (`bin/ainish-coder`): Main command-line interface written in Bash
- **CONFIGURATIONS** (`CONFIGURATIONS/`): Centralized storage for tool-specific configs
- **TIER_RULES** (`TIER_*_RULES/`): Modular rule sets organized by priority
- **Setup Script** (`ainish-setup.sh`): Installation and PATH configuration

### Design Principles

1. **Modularity**: Rules and configs are separated by tool and priority
2. **Simplicity**: Single bash script CLI with clear command structure
3. **Extensibility**: Easy to add new tiers or tool configurations
4. **Portability**: Works across Unix-like systems (macOS, Linux)

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