# ```bibtex
@misc{ainish-coder2025,
  author/creator/steward = {ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians},
  title/description = {ainish-coder},
  type_of_work = {Indigenous digital creation/software incorporating traditional knowledge and cultural expressions},
  year = {2025},
  publisher/source/event = {GitHub repository under tribal sovereignty protections},
  howpublished = {\url{https://github.com/nbiish/ainish-coder}},
  note = {Authored and stewarded by ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Indigenous intellectual property, traditional knowledge systems (TK), traditional cultural expressions (TCEs), and associated data protected under tribal law, federal Indian law, treaty rights, Indigenous Data Sovereignty principles, and international indigenous rights frameworks including UNDRIP. All usage, benefit-sharing, and data governance are governed by the COMPREHENSIVE RESTRICTED USE LICENSE FOR INDIGENOUS CREATIONS WITH TRIBAL SOVEREIGNTY, DATA SOVEREIGNTY, AND WEALTH RECLAMATION PROTECTIONS.}
```

# ◈──◆──◇ ainish-coder ◇──◆──◈

<div align="center">
  <h2>Configuration manager for AI coding assistants</h2>
  <p>Simple deployment of MAI RULES and AGENTS.md configurations to your projects.</p>
  <p><strong>✨ Now supports AGENTS.md - the universal standard for AI pair programmers</strong></p>

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

## 🎯 What's New: AGENTS.md Single Source of Truth

**AGENTS.md** is the universal standard for AI pair programmer instructions (August 2025). This tool now enforces a **simplified workflow**:

- ✅ **Run --agents first** to create AGENTS.md at project root
- ✅ **All tools symlink to AGENTS.md** - no copies, no fallbacks
- ✅ **Single source of truth** - edit once, applies everywhere
- ⚠️ **Required workflow** - tool commands fail if AGENTS.md doesn't exist

See [AGENTS.md Compatibility Matrix](KNOWLEDGE_BASE/AGENTS-MD-COMPATIBILITY.md) for full details.

## Capabilities

- **AGENTS.md Standard**: Deploy universal AI agent instructions
- **Modular Architecture**: Clean Atom → Molecule → Matter structure
- **Multiple AI Tools**: GitHub Copilot, Continue Dev, Qwen, Gemini, Cline, Windsurf, Roo Code
- **Simple Deployment**: One command to deploy configurations
- **Smart Symlinks**: Unified configuration across tools
- **Shell Integration**: Convenient `ainish-coder` command

## Installation

### Prerequisites
- Git
- Terminal (zsh, bash, or PowerShell)

### Quick Install

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

**Windows PowerShell:**
```powershell
.\ainish-setup.sh
. $PROFILE
```

## Usage

### Recommended Workflow (AGENTS.md Standard)

⚠️ **IMPORTANT:** Always run `--agents` first to create AGENTS.md before using any tool commands.

```bash
# Step 1: Deploy AGENTS.md (REQUIRED FIRST)
ainish-coder --agents /path/to/project

# Step 2: Deploy tool-specific symlinks (these will fail without AGENTS.md)
ainish-coder --copilot /path/to/project   # Creates .github/copilot-instructions.md → AGENTS.md
ainish-coder --cursor /path/to/project    # Creates .cursor/rules/AGENTS.md → AGENTS.md
ainish-coder --cline /path/to/project     # Creates .clinerules/AGENTS.md → AGENTS.md
ainish-coder --windsurf /path/to/project  # Creates .windsurf/rules/rules.md → AGENTS.md
ainish-coder --cn /path/to/project        # Creates .continue/rules/AGENTS.md → AGENTS.md
ainish-coder --gemini /path/to/project    # Creates GEMINI.md → AGENTS.md
ainish-coder --qwen /path/to/project      # Creates QWEN.md → AGENTS.md
ainish-coder --roocode /path/to/project   # Creates .roo/AGENTS.md → AGENTS.md + .rooignore

# Step 3 (Optional): Deploy supplementary MAIRULES.md
ainish-coder --mairules /path/to/project  # Creates .mai-rules/MAIRULES.md

# Step 4 (Optional): Symlink critical.md to project root
ainish-coder --critical /path/to/project  # Creates critical.md → TIER_0/critical.md

# Step 5 (Optional): Deploy comprehensive .gitignore
ainish-coder --gitignore /path/to/project # Creates .gitignore with AI tool patterns
```

**Result:** All tools now use a single `AGENTS.md` file! Changes to AGENTS.md automatically propagate to all tools.

**What happens if you skip --agents?**
```bash
$ ainish-coder --copilot /path/to/project
❌ Error: AGENTS.md not found
💡 Run first: ainish-coder --agents /path/to/project
```

### Quick Reference

```bash
# Universal standard
ainish-coder --agents        # Deploy AGENTS.md (recommended first)
ainish-coder --mairules      # Alternative: Deploy MAIRULES.md
ainish-coder --critical      # Symlink critical.md to project root
ainish-coder --gitignore     # Deploy comprehensive .gitignore

# Tool-specific deployments
ainish-coder --copilot       # GitHub Copilot (→ AGENTS.md)
ainish-coder --cn            # Continue Dev (→ AGENTS.md)
ainish-coder --cline         # Cline (→ AGENTS.md)
ainish-coder --windsurf      # Windsurf (→ AGENTS.md)
ainish-coder --gemini        # Gemini (→ AGENTS.md)
ainish-coder --roocode       # Roo Code (proprietary format)
ainish-coder --qwen          # Qwen AI (custom format)

# Show all options
ainish-coder --help
```

### Global Installation (User Home Directory)

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

**Configuration Hierarchy:**
1. `AGENTS.md` (working directory) - **universal standard, highest priority**
2. `MAIRULES.md` (working directory) - alternative format
3. `.mai-rules/MAIRULES.md` (project config)
4. `~/.mai-rules/MAIRULES.md` (global fallback)
5. Default AI tool behavior

**Note:** Global installations are for tool-specific configuration files in their global spaces. For project-level rules deployment (including Cline and Roo Code), use the project-level commands below.

### Project-Level Deployment

Deploy configurations to your project directory:

```bash
# Show all options
ainish-coder --help

# Deploy MAI RULES (Universal rules for all AI tools)
ainish-coder --mairules /path/to/project

# Deploy for GitHub Copilot
ainish-coder --copilot /path/to/project

# Deploy for Continue Dev
ainish-coder --cn /path/to/project

# Deploy for Qwen AI
ainish-coder --qwen /path/to/project

# Deploy for Google Gemini
ainish-coder --gemini /path/to/project

# Deploy for Cline
ainish-coder --cline /path/to/project

# Deploy for Roo Code
ainish-coder --roocode /path/to/project

# Deploy specific tier rules to current working directory
ainish-coder --tier0   # TIER_0: Critical rules (LICENSE, CONTRIBUTING, etc.)
ainish-coder --tier1   # TIER_1: Core rules (structure, code-judge, PRD, etc.)
ainish-coder --tier2   # TIER_2: Security rules (code-security, prompt-security)
ainish-coder --tier3   # TIER_3: Style & advanced rules (anishinaabe-cyberpunk, modern-prompting)

# Deploy all tiers at once
ainish-coder --all-tiers /path/to/project

# Clear all deployed rules (useful for batch testing)
ainish-coder --clear-all-rules /path/to/project
```

## What Gets Deployed

### AGENTS.md (`--agents`) **⭐ Required First**

Copies `TIER_1_RULES/MAIRULES.md` → `AGENTS.md` at project root:
- ✅ Creates the single source of truth for all AI tools
- ✅ Must be run before any tool commands
- ✅ All other tools symlink to this file

### MAIRULES.md (`--mairules`)

Copies `TIER_1_RULES/MAIRULES.md` → `.mai-rules/MAIRULES.md`:
- 📋 Supplementary resource (AGENTS.md points to this location)
- 📋 Additional context for tools that support multiple rule files

### Critical.md (`--critical`)

Creates symlink: `critical.md` → `TIER_0/critical.md`
- 🔒 Project-critical rules and constraints
- 🔒 Always visible at project root

### Gitignore (`--gitignore`)

Creates comprehensive `.gitignore` file with:
- 🤖 AI pair programmer tool exclusions (.cursor/, .continue/, etc.)
- 🔐 Environment variables and secrets
- 🐍 Python virtual environments and cache
- 📦 Node.js dependencies
- 💻 IDE/editor files
- 🗂️ OS-generated files
- 📝 Backup and temporary files
- ⚠️ Backs up existing .gitignore before replacement

### GitHub Copilot (`--copilot`)

Creates symlink: `.github/copilot-instructions.md` → `../AGENTS.md`
- ⚠️ Requires AGENTS.md to exist first
- ✅ Native AGENTS.md support

### Cursor (`--cursor`)

Creates symlink: `.cursor/rules/AGENTS.md` → `../../AGENTS.md`
- ⚠️ Requires AGENTS.md to exist first
- ✅ Native AGENTS.md support

### Continue Dev (`--cn`)

Creates symlink: `.continue/rules/AGENTS.md` → `../../AGENTS.md`
- ⚠️ Requires AGENTS.md to exist first
- ✅ Native AGENTS.md support

### Cline (`--cline`)

Creates symlink: `.clinerules/AGENTS.md` → `../AGENTS.md`
- ⚠️ Requires AGENTS.md to exist first
- 🔗 Symlink-based AGENTS.md support

### Windsurf (`--windsurf`)

Creates symlink: `.windsurf/rules/rules.md` → `../../AGENTS.md`
- ⚠️ Requires AGENTS.md to exist first
- 🔗 Reads `rules.md` which points to AGENTS.md

### Gemini (`--gemini`)

Creates symlink: `GEMINI.md` → `AGENTS.md`
- ⚠️ Requires AGENTS.md to exist first
- ✅ Native AGENTS.md support (reads GEMINI.md)

### Qwen AI (`--qwen`)

Creates symlink: `QWEN.md` → `AGENTS.md`
- ⚠️ Requires AGENTS.md to exist first
- ✅ Native AGENTS.md support (reads QWEN.md)

### Roo Code (`--roocode`)

Creates symlink: `.roo/AGENTS.md` → `../AGENTS.md` + `.rooignore`
- ⚠️ Requires AGENTS.md to exist first
- ✅ Native AGENTS.md support

### Tier-Based Deployments

Deploy specific rule tiers to your current working directory:

- **`--tier0`**: TIER_0 Critical rules → `.mai-rules/*.md`
  - LICENSE, CONTRIBUTING.md, README.md requirements
  - Always-apply critical guidelines

- **`--tier1`**: TIER_1 Core rules → `.mai-rules/*.md`
  - MAIRULES.md (universal rules)
  - Core foundation rules

- **`--tier2`**: TIER_2 Documentation & PRD → `.mai-rules/*.md`
  - Documentation usage guidelines
  - PRD templates

- **`--tier3`**: TIER_3 Security rules → `.mai-rules/*.md`
  - Code security best practices
  - Prompt security guidelines

- **`--tier4`**: TIER_4 Style & Advanced → `.mai-rules/*.md`
  - Anishinaabe-Cyberpunk styling (optional)
  - Modern prompting techniques (OOReDAct)

- **`--all-tiers`**: Deploy all tiers at once

- **`deploy_markdown`**: Deploy all tiers (same as --all-tiers, all files already .md)

### Maintenance Commands

- **`--clear-all-rules`**: Remove all deployed AINISH-Coder rules from a directory
  - **Local workspace files:**
    - Removes `.github/copilot-instructions.md`
    - Removes `.continue/rules/MAIRULES.md` and empty directories
    - Removes `QWEN.md`, `GEMINI.md`, `MAIRULES.md`
    - Removes entire `.mai-rules/` directory with all tier files
  - **Global configuration files:**
    - Removes `~/.gemini/` directory (Gemini AI global settings)
    - Removes `~/.qwen/` directory (Qwen AI global settings)
  - Safe to run multiple times - only removes AINISH-Coder files
  - Useful for batch testing different configurations across multiple AI tools

## Directory Structure

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

## Configuration Files

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

### File Format

All configuration files are now `.md` (Markdown) format for better compatibility with all AI coding assistants.

## Troubleshooting

### Command not found
```bash
# Reload your shell configuration
source ~/.zshrc  # or ~/.bashrc

# Or restart your terminal
```

### Permission denied
```bash
# Make script executable
chmod +x ainish-setup.sh
```

### Shell wrapper issues
```bash
# Re-run setup to recreate wrappers
./ainish-setup.sh
```

## Architecture

This project follows the **Atom → Molecule → Matter** pattern from `structure.mdc`:

- **Atoms** (`lib/atoms/`): Basic functions (colors, paths, file operations)
- **Molecules** (`lib/molecules/`): Feature modules (deployment logic)
- **Matter** (`ainish-setup.sh`): Main orchestrator

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License
See [LICENSE](LICENSE) for details.

---

Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), a descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band, and an enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Traditional Knowledge and Traditional Cultural Expressions. All rights reserved.

<div align="center">
  <p>◈──◆──◇ Made with ♥ by the AINISH community ◇──◆──◈</p>
</div>
