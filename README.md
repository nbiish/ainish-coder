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
# Step 1: Deploy AGENTS.md (REQUIRED FIRST)
ainish-coder --agents /path/to/project

# Step 2: Deploy tool-specific configurations
ainish-coder --cursor /path/to/project    # Cursor AI
ainish-coder --copilot /path/to/project   # GitHub Copilot
ainish-coder --cline /path/to/project     # Cline
ainish-coder --windsurf /path/to/project  # Windsurf
```

## 🎯 What's New: AGENTS.md Single Source of Truth

**AGENTS.md** is the universal standard for AI pair programmer instructions (August 2025). This tool now enforces a **simplified workflow**:

- ✅ **Run --agents first** to create AGENTS.md at project root
- ✅ **All tools symlink to AGENTS.md** - no copies, no fallbacks
- ✅ **Single source of truth** - edit once, applies everywhere
- ⚠️ **Required workflow** - tool commands fail if AGENTS.md doesn't exist

See [AGENTS.md Compatibility Matrix](KNOWLEDGE_BASE/AGENTS-MD-COMPATIBILITY.md) for full details.

## 🛠️ Supported AI Tools

| Tool | Command | Status |
|------|---------|--------|
| **AGENTS.md** | `--agents` | ⭐ **Universal Standard** |
| **Cursor** | `--cursor` | ✅ Native AGENTS.md support |
| **GitHub Copilot** | `--copilot` | ✅ Native AGENTS.md support |
| **Continue Dev** | `--cn` | ✅ Native AGENTS.md support |
| **Cline** | `--cline` | 🔗 Symlink-based support |
| **Windsurf** | `--windsurf` | 🔗 Reads rules.md → AGENTS.md |
| **Gemini** | `--gemini` | ✅ Native AGENTS.md support |
| **Qwen AI** | `--qwen` | ✅ Native AGENTS.md support |
| **Roo Code** | `--roocode` | ✅ Native AGENTS.md support |

## 📋 Complete Usage Guide

### Recommended Workflow

⚠️ **IMPORTANT:** Always run `--agents` first to create AGENTS.md before using any tool commands.

```bash
# Step 1: Deploy AGENTS.md (REQUIRED FIRST)
ainish-coder --agents /path/to/project  # or --rules

# Step 2: Deploy tool-specific symlinks
ainish-coder --copilot /path/to/project   # Creates .github/copilot-instructions.md → ../AGENTS.md
ainish-coder --cursor /path/to/project    # Creates .cursor/rules/AGENTS.md → ../../AGENTS.md
ainish-coder --cline /path/to/project     # Creates .clinerules/AGENTS.md → ../AGENTS.md
ainish-coder --windsurf /path/to/project  # Creates .windsurf/rules/rules.md → ../../AGENTS.md
ainish-coder --cn /path/to/project        # Creates .continue/rules/AGENTS.md → ../../AGENTS.md
ainish-coder --gemini /path/to/project    # Creates GEMINI.md → AGENTS.md
ainish-coder --qwen /path/to/project      # Creates QWEN.md → AGENTS.md
ainish-coder --roocode /path/to/project   # Creates .roo/AGENTS.md → ../AGENTS.md + .rooignore

# Optional: Deploy supplementary configurations
ainish-coder --mairules /path/to/project  # Creates .mai-rules/MAIRULES.md
ainish-coder --critical /path/to/project  # Creates critical.md → TIER_0/critical.md
ainish-coder --gitignore /path/to/project # Creates comprehensive .gitignore
```

**Result:** All tools now use a single `AGENTS.md` file! Changes to AGENTS.md automatically propagate to all tools.

### Global Installation

Install rules globally for system-wide access:

```bash
# Install all global rules
ainish-coder --install-global

# Or install specific tools
ainish-coder --install-global-mai       # Install MAI RULES to ~/.mai-rules/
ainish-coder --install-global-qwen      # Install Qwen rules to ~/.qwen/
ainish-coder --install-global-gemini    # Install Gemini rules to ~/.gemini/
ainish-coder --install-global-continue  # Install Continue reference to ~/.continue/
```

### Configuration Hierarchy

1. `AGENTS.md` (working directory) - **universal standard, highest priority**
2. `MAIRULES.md` (working directory) - alternative format
3. `.mai-rules/MAIRULES.md` (project config)
4. `~/.mai-rules/MAIRULES.md` (global fallback)
5. Default AI tool behavior

## 📁 Project Structure

```
ainish-coder/
├── ainish-setup.sh          # Main entry point (Matter)
├── TIER_0/                  # Critical rules (highest priority)
│   └── critical.md
├── TIER_1_RULES/            # Core rules (foundation)
│   ├── MAIRULES.md          # Universal rules (consolidated)
│   └── ... (other core rules moved here)
├── TIER_2_RULES/            # Documentation & PRD
│   ├── docs-use.md
│   └── PRD.md
├── TIER_3_RULES/            # Security rules
│   ├── code-security.md
│   └── prompt-security.md
├── TIER_4_RULES/            # Style & advanced rules
│   ├── anishinaabe-cyberpunk-style.md
│   └── modern-prompting.md
└── lib/
    ├── atoms/               # Core functions
    │   ├── colors.sh
    │   ├── paths.sh
    │   ├── file_operations.sh
    │   ├── validation.sh
    │   └── backup.sh
    └── molecules/           # Feature modules
        ├── help.sh
        ├── deploy_copilot.sh
        ├── deploy_continue.sh
        ├── deploy_qwen.sh
        ├── deploy_gemini.sh
        ├── deploy_mairules.sh
        ├── deploy_tiers.sh
        └── ...
```

## 🎨 Configuration Files

Rules are organized into tiers for different priority levels:

### TIER_0 (Critical - Highest Priority)
- **critical.md**: LICENSE, CONTRIBUTING.md, README.md requirements
- Always-apply guidelines for all projects

### TIER_1 (Core - Foundation Rules)
- **MAIRULES.md**: Universal rules (consolidated)
- Core foundation rules for all AI tools

### TIER_2 (Documentation & PRD - High Priority)
- **docs-use.md**: Documentation usage best practices
- **PRD.md**: Product Requirements Document templates

### TIER_3 (Security - Medium-High Priority)
- **code-security.md**: Code security best practices
- **prompt-security.md**: Prompt injection & AI security

### TIER_4 (Style & Advanced - Medium Priority)
- **anishinaabe-cyberpunk-style.md**: Optional cultural styling
- **modern-prompting.md**: OOReDAct framework & advanced prompting

## 🏗️ Architecture

This project follows the **Atom → Molecule → Matter** pattern:

- **Atoms** (`lib/atoms/`): Basic functions (colors, paths, file operations)
- **Molecules** (`lib/molecules/`): Feature modules (deployment logic)
- **Matter** (`ainish-setup.sh`): Main orchestrator

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