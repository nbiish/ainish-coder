# ◈──◆──◇ ainish-coder ◇──◆──◈

<div align="center">
  <h1>🚀 Configuration Manager for AI Coding Assistants</h1>
  <p><strong>Simple deployment of MAI RULES and AGENTS.md configurations to your projects</strong></p>
  <p>✨ <em>Now supports AGENTS.md - the universal standard for AI pair programmers</em></p>

  <hr width="60%">

  <h2>🎯 What is ainish-coder?</h2>
  <p><strong>ainish-coder</strong> is a powerful configuration management tool that simplifies deploying AI coding assistant rules across multiple platforms. It creates a unified configuration system using the emerging AGENTS.md standard, ensuring consistent AI behavior across all your development tools.</p>
</div>

<div align="center">
  <hr width="50%">
  <h3>Support This Project</h3>
  <table style="border: none; border-collapse: collapse;">
    <tr style="border: none;">
      <td align="center" style="border: none; vertical-align: middle; padding: 20px;">
        <h4>Stripe</h4>
        <img src="qr-stripe-donation.png" alt="Scan to donate" width="180"/>
        <p><a href="https://raw.githubusercontent.com/nbiish/license-for-all-works/8e9b73b269add9161dc04bbdd79f818c40fca14e/qr-stripe-donation.png">Donate via Stripe</a></p>
      </td>
      <td align="center" style="border: none; vertical-align: middle; padding: 20px;">
        <a href="https://www.buymeacoffee.com/nbiish">
          <img src="buy-me-a-coffee.svg" alt="Buy me a coffee" />
        </a>
      </td>
    </tr>
  </table>
  <hr width="50%">
</div>

## 🔥 Key Features

- **🎯 AGENTS.md Standard**: Deploy universal AI agent instructions
- **🏗️ Modular Architecture**: Clean Atom → Molecule → Protein structure
- **🤖 Multiple AI Tools**: GitHub Copilot, Continue Dev, Qwen, Gemini, Cline, Windsurf, Roo Code, and Trae
- **🔄 OSA (Ralph-First) Framework**: Mandatory Ralph Loop orchestration with Gemini/Qwen/Opencode agents
- **⚡ Simple Deployment**: One command to deploy configurations
- **🔗 Smart File Management**: Copies configurations to ensure tool-specific customization
- **💻 Shell Integration**: Convenient `ainish-coder` command
- **🎭 Template Agent System**: Craft custom system prompts with expert guidance
- **🛡️ Local Secret Protection**: Auto-sanitize known keys and generate a local security report for remediation

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
ainish-coder --rules                     # Deploy AGENTS.md, empty MAIRULES.md, critical.md, .gitignore, and llms.txt

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

## 🛠️ Supported AI Tools

### IDE Extensions

| Tool | Config Flag | Commands Flag | Rules Target | Commands Target | Format |
|------|------------|---------------|--------------|-----------------|--------|
| **Cursor** | `--cursor` | `--commands cursor` | `.cursor/rules/` | `.cursor/commands/*.md` | Plain markdown |
| **Roo Code** | `--roocode` | `--commands roocode` | `.roo/rules/` | `.roo/commands/*.md` | Markdown + frontmatter |
| **Windsurf** | `--windsurf` | `--commands windsurf` | `.windsurf/rules/` | `.windsurf/workflows/*.md` | Workflows |
| **Cline** | `--cline` | `--commands cline` | `.clinerules/` | `.clinerules/*.md` | Rules files |
| **Continue Dev** | `--continue` | `--commands continue` | `.continue/rules/` | Config guide | config.yaml setup |
| **GitHub Copilot** | `--copilot` | N/A | `.github/copilot-instructions.md` | N/A | Copied |
| **Trae** | `--trae` | N/A | `.trae/rules/` | N/A | Markdown |

### CLI Tools

| Tool | Config Flag | Commands Flag | Rules Target | Commands Target | Format |
|------|------------|---------------|--------------|-----------------|--------|
| **Gemini CLI** | `--gemini` | `--commands gemini-cli` | `.gemini/` | `.gemini/commands/*.toml` | TOML |
| **Qwen Code** | `--qwen` | `--commands qwen` | `QWEN.md` | `.qwen/commands/*.toml` | TOML |

## 🎨 Tier Rules Explained

Rules are organized into tiers by priority and purpose:

- **TIER_0 (Documentation)**: `docs-protocol.md` - Documentation standards and best practices (Critical)
- **TIER_1 (Code Security)**: `code-security.md` - Comprehensive code security best practices (High)
- **TIER_2 (Prompt Security)**: `prompt-security.md` - AI prompt injection defense and security (High)
- **TIER_3 (Cultural Style)**: `anishinaabe-cyberpunk-style.md` - Anishinaabe cyberpunk aesthetic preferences (Medium)
- **TIER_4 (Advanced Prompting)**: `modern-prompting.md` - OOReDAct framework and advanced prompting techniques (Medium)

## 🏗️ Architecture

The tool is built with a modular, extensible design following the Atomic Design pattern:

- **CLI Tool** (`bin/ainish-coder`): Main command-line interface
- **Atoms** (`dna/atoms/`): Core utilities (colors, paths, validation, file operations)
- **Molecules** (`dna/molecules/`): Deployment functions (deploy_*.sh)
- **Proteins** (`dna/proteins/`): Higher-level orchestration
- **CONFIGURATIONS** (`CONFIGURATIONS/`): Centralized tool-specific configs (now centralized in `.configs/`)
- **TIER_RULES** (`TIER_RULES/`): Modular rule sets organized by priority

## 📚 Citation

```bibtex
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

## ⚖️ Copyright

```markdown
Copyright © 2026 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), a descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band, and an enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Traditional Knowledge and Traditional Cultural Expressions. All rights reserved.
```

## 📜 License & Contributing

Please refer to the current [LICENSE](LICENSE) and [CONTRIBUTING.md](CONTRIBUTING.md) files for legal terms and contribution guidelines.

---

<div align="center">
  <p>◈──◆──◇ Made with ♥ by the AINISH community ◇──◆──◈</p>
</div>
