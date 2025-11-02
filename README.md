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
# Deploy core rules files (RECOMMENDED FIRST STEP)
ainish-coder --rules                     # Deploy AGENTS.md and MAIRULES.md (both files)

# Deploy tier-specific rules (appends to MAIRULES.md)
ainish-coder --tier 0                    # Append TIER_0 to MAIRULES.md (Documentation protocols)
ainish-coder --tier 1                    # Append TIER_1 to MAIRULES.md (Code security)
ainish-coder --tier all                  # Append all tiers (0-4) to MAIRULES.md

# Deploy tool-specific configurations
ainish-coder --cursor                    # Deploy to .cursor/rules/
ainish-coder --windsurf                  # Deploy to .windsurf/rules/

# Deploy custom commands to current directory
ainish-coder --commands cursor           # Deploy slash commands from CONFIGURATIONS
ainish-coder --commands windsurf         # Deploy workflow commands

# Utility commands
ainish-coder --gitignore                 # Create comprehensive .gitignore
ainish-coder --critical                  # Create symlink to critical documentation
```

## 🎯 What's New

### 🆕 Tier-Based Rule Deployment

Deploy modular rule sets organized by priority and purpose. **Tiers append to MAIRULES.md** for consolidated rule management:

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

Deploy tool-specific slash commands and workflows directly from the `CONFIGURATIONS/` directory to your current project.

## 🛠️ Supported AI Tools

| Tool | Configuration Flag | Commands Flag | Target |
|------|-------------------|---------------|--------|
| **Cursor** | `--cursor` | `--commands cursor` | `.cursor/rules/` + `cursor/commands/` |
| **Windsurf** | `--windsurf` | `--commands windsurf` | `.windsurf/rules/` + `windsurf/commands/` |
| **Cline** | `--cline` | N/A | `.clinerules/` |
| **GitHub Copilot** | `--copilot` | N/A | `.github/copilot-instructions.md` (symlink) |
| **Continue Dev** | `--continue` | N/A | `.continue/rules/` (symlink) |
| **Gemini CLI** | `--gemini` | N/A | `.gemini/` |
| **Qwen Code** | `--qwen` | N/A | `QWEN.md` (symlink) |
| **Roo Code** | `--roocode` | N/A | `.roo/rules/` |
| **Goose CLI** | `--goose` | N/A | � Coming soon |

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

# Step 5: Add utilities (optional)
ainish-coder --gitignore                 # Create comprehensive .gitignore
ainish-coder --critical                  # Symlink to critical documentation
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
- Deploys AGENTS.md and MAIRULES.md to tool-specific directories
- Some use symlinks (Copilot, Continue, Qwen), others copy files
- Requires AGENTS.md/MAIRULES.md to exist first (run `--rules` first)

**Custom Commands** (`--commands {tool}`):
- Deploys tool-specific commands from `CONFIGURATIONS/.{tool}/commands/`
- Creates `{tool}/commands/` directory structure
- Currently available: cursor, windsurf

**Utilities**:
- `--gitignore`: Creates comprehensive .gitignore (225 lines)
- `--critical`: Creates symlink to TIER_0 documentation protocol

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

| Tool | Configuration Command | Commands Deployment | Notes |
|------|----------------------|---------------------|-------|
| **Cursor** | `--cursor` | `--commands cursor` | Copies to `.cursor/rules/` + deploys commands |
| **Windsurf** | `--windsurf` | `--commands windsurf` | Copies to `.windsurf/rules/` + deploys workflows |
| **Cline** | `--cline` | N/A | Copies to `.clinerules/` |
| **GitHub Copilot** | `--copilot` | N/A | Symlinks `.github/copilot-instructions.md` |
| **Continue Dev** | `--continue` | N/A | Symlinks `.continue/rules/AGENTS.md` |
| **Gemini CLI** | `--gemini` | N/A | Copies to `.gemini/` |
| **Qwen Code** | `--qwen` | N/A | Symlinks `QWEN.md` to AGENTS.md |
| **Roo Code** | `--roocode` | N/A | Copies to `.roo/rules/` |

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
├── population/                # Modular architecture
│   ├── atoms/                 # Core utilities (colors, paths, validation)
│   ├── molecules/             # Deployment functions (deploy_*.sh)
│   └── organisms/             # Future: higher-level orchestration
├── TIER_0_RULES/              # Critical documentation protocols
│   └── docs-protocol.md
├── TIER_1_RULES/              # Code security
│   └── code-security.md
├── TIER_2_RULES/              # Prompt security
│   └── prompt-security.md
├── TIER_3_RULES/              # Cultural styling
│   └── anishinaabe-cyberpunk-style.md
├── TIER_4_RULES/              # Advanced prompting
│   └── modern-prompting.md
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
- **Atoms** (`population/atoms/`): Core utilities (colors, paths, validation, file operations)
- **Molecules** (`population/molecules/`): Deployment functions (deploy_*.sh)
- **Organisms** (`population/organisms/`): Future: higher-level orchestration
- **CONFIGURATIONS** (`CONFIGURATIONS/`): Centralized tool-specific configs
- **TIER_RULES** (`TIER_*_RULES/`): Modular rule sets organized by priority

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