# AI Tool Configuration Locations Reference

**Last Updated:** October 27, 2025

This document provides a comprehensive reference for where each AI coding tool reads its configuration files, based on official documentation and current implementation status in `ainish-coder`.

---

## Currently Supported Tools

All 8 major AI coding tools are now fully supported!

### 1. Cursor AI ✅ **IMPLEMENTED**

**Configuration Location:**
- **Primary:** `./.cursor/rules/` (project-level)
- **File Format:** `.mdc` files
- **Command:** `ainish-coder`

**Details:**
- Project-specific configuration
- Version controlled with your project
- All `.mdc` files in `RULES_WE_WANT/` are deployed

**Status:** ✅ Fully implemented and working

---

### 2. VSCode GitHub Copilot ✅ **IMPLEMENTED**

**Configuration Location:**
- **Primary:** `./.github/copilot-instructions.md` (repository-level)
- **Secondary:** `./.github/instructions/*.instructions.md` (path-specific)
- **File Format:** `.md` files
- **Command:** `ainish-coder --vscode`

**Structure:**
```
.github/
├── copilot-instructions.md          # Consolidated instructions
└── instructions/
    ├── modern-prompting.instructions.md
    └── anishinaabe-cyberpunk-style.instructions.md
```

**Official Documentation:**
- [Add Repository Custom Instructions](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions)

**Status:** ✅ Fully implemented with structured distribution

---

### 3. GitHub Copilot CLI ✅ **PARTIALLY SUPPORTED**

**Configuration Locations:**
- **User Config:** `~/.config/config.json` (user-level settings)
- **MCP Servers:** `~/.config/mcp-config.json` (Model Context Protocol)
- **Repository Instructions:** `./.github/copilot-instructions.md` (same as VSCode)

**Environment Variables:**
- `XDG_CONFIG_HOME` - Override default config directory (default: `~/.config`)

**File Formats:**
- `.json` for user configuration
- `.md` for repository instructions

**Features:**
- Reads repository custom instructions from `.github/copilot-instructions.md`
- Supports path-specific instructions: `.github/copilot-instructions/**/*.instructions.md`
- MCP server configuration for extended functionality
- Trusted directories configuration

**Official Documentation:**
- [Using GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli)
- [About GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli)

**Status:** ✅ Uses existing VSCode deployment (`.github/copilot-instructions.md`)
**Note:** User config (`~/.config/config.json`) is managed by GitHub CLI, not by `ainish-coder`

---

### 4. Qwen AI ✅ **IMPLEMENTED**

**Configuration Locations:**
- **Primary:** `~/.qwen/QWEN.md` (user-level, consolidated)
- **Secondary:** `./.ainish-coder/*.md` (project-level, individual files)
- **File Format:** `.md` files
- **Command:** `ainish-coder --qwen`

**Structure:**
```
~/.qwen/
└── QWEN.md                          # Consolidated from most .mdc files

./.ainish-coder/                     # Excluded from consolidation
├── anishinaabe-cyberpunk-style.md
├── prompt-security.md
├── critical.md
├── code-security.md
├── KNOWLEDGE_BASE.md
└── PRD.md
```

**Excluded from Consolidation:**
- `anishinaabe-cyberpunk-style.mdc`
- `prompt-security.mdc`
- `critical.mdc`
- `code-security.mdc`
- `KNOWLEDGE_BASE.mdc`
- `PRD.mdc`

**Status:** ✅ Fully implemented with consolidated + separate structure

---

### 5. Google Gemini ✅ **IMPLEMENTED**

**Configuration Locations:**
- **Primary:** `~/.gemini/GEMINI.md` (user-level, consolidated)
- **Secondary:** `./.ainish-coder/*.md` (project-level, individual files)
- **File Format:** `.md` files
- **Command:** `ainish-coder --gemini`

**Structure:**
```
~/.gemini/
└── GEMINI.md                        # Consolidated from most .mdc files

./.ainish-coder/                     # Excluded from consolidation
├── anishinaabe-cyberpunk-style.md
├── prompt-security.md
├── critical.md
├── code-security.md
├── KNOWLEDGE_BASE.md
└── PRD.md
```

**Excluded from Consolidation:** (Same as Qwen)
- `anishinaabe-cyberpunk-style.mdc`
- `prompt-security.mdc`
- `critical.mdc`
- `code-security.mdc`
- `KNOWLEDGE_BASE.mdc`
- `PRD.mdc`

**Status:** ✅ Fully implemented with consolidated + separate structure

---

## Tools Needing Implementation

### 6. Continue Dev (CLI: `cn`) ✅ **IMPLEMENTED**

**Configuration Locations:**
- **Primary (Reference):** `~/.continue/CONTINUE.md` (user-level, consolidated)
- **Secondary:** `./.ainish-coder/*.md` (project-level, individual files)
- **Active Config:** `~/.continue/config.yaml` (user-level)
- **Legacy (Deprecated):** `~/.continue/config.json`
- **Advanced (Optional):** `~/.continue/config.ts` (programmatic)
- **Workspace (Deprecated):** `./.continuerc.json`

**Platform Paths:**
- **macOS/Linux:** `~/.continue/config.yaml`
- **Windows:** `%USERPROFILE%\.continue\config.yaml`

**File Formats:**
- **YAML** (current standard for active config)
- **Markdown** (reference documentation)
- **JSON** (legacy, still supported)
- **TypeScript** (advanced programmatic config)

**Configuration Access:**
- Via gear icon in Continue sidebar
- Direct file editing in home directory

**Official Documentation:**
- [Continue Configuration Deep Dive](https://docs.continue.dev/customize/deep-dives/configuration)

**Deployment:**
```bash
# Deploy to Continue Dev
ainish-coder --continue

# Deploys to:
~/.continue/CONTINUE.md           # Consolidated reference doc
./.ainish-coder/*.md             # Project-level reference docs
```

**Status:** ✅ **FULLY IMPLEMENTED**

**Implementation Details:**
1. ✅ Created `deploy_continue_structured()` function in `ainish-setup.sh`
2. ✅ Generate CONTINUE.md reference document with AINISH settings
3. ✅ Deploy reference docs to `./.ainish-coder/`
4. ✅ Add command alias: `ainish-coder --continue`
5. ✅ Updated documentation in README.md and AI-TOOL-CONFIG-LOCATIONS.md

**Structure:**
```plaintext
~/.continue/

---

### 7. Cline ✅ **IMPLEMENTED**

**Configuration Locations:**
- **Global Rules:** `~/Documents/Cline/Rules/` (Cline's native global location, user-managed)
- **Project Rules:** `./.clinerules/` (directory with multiple `.md` files, deployed by ainish-coder)
- **Also Reads:** `.cursorrules` and `.windsurfrules` files
- **File Format:** `.md` files
- **Command:** `ainish-coder --cline`

**ainish-coder Deployment:**
```
./.clinerules/                     # Project-specific rules (deployed by --cline)
├── MAIRULES.md
├── docs-use.md
└── PRD.md
```

**Note:** The `--cline` command deploys project-level rules only. The global directory (`~/Documents/Cline/Rules/`) is Cline's native feature and can be managed manually by users for their personal global rules.

**Key Features:**
- Automatically loads all `.md` files from `.clinerules/` directory
- Global rules apply to all projects
- Supports slash commands like `/newrule` to create new rules
- Can toggle rules on/off from UI
- Supports workflows in `.clinerules/workflows/`

**Official Documentation:**
- [Cline GitHub Repository](https://github.com/cline/cline)
- [Cline Rules Documentation](https://docs.cline.bot/features/cline-rules)

**Status:** ✅ Fully implemented with global and project-level support

---

### 8. Roo Code ✅ **IMPLEMENTED**

**Configuration Locations:**
- **Global Rules:** `~/Documents/Cline/Rules/` (Roo Code's native global location, user-managed, shared with Cline)
- **Project Rules:** `./.roo/` (directory with multiple `.md` files, deployed by ainish-coder)
- **Ignore File:** `.rooignore` (similar to `.gitignore`, created by ainish-coder)
- **Modes File:** `.roomodes` (custom modes configuration, user-managed)
- **File Format:** `.md` files
- **Command:** `ainish-coder --roocode`

**ainish-coder Deployment:**
```
./.roo/                           # Project-specific rules (deployed by --roocode)
├── MAIRULES.md
├── docs-use.md
└── PRD.md

.rooignore                        # Auto-generated exclusion file
```

**Note:** The `--roocode` command deploys project-level rules and creates `.rooignore`. The global directory (`~/Documents/Cline/Rules/`) is Roo Code's native feature shared with Cline and can be managed manually by users for their personal global rules.

**Key Features:**
- Fork of Cline with additional enterprise features
- Multiple modes: Code, Architect, Ask, Debug, Custom
- Roomote Control for remote task management
- Automatically loads all `.md` files from `.roo/` directory
- Checkpoint system for task versioning
- Todo list management

**Official Documentation:**
- [Roo Code GitHub Repository](https://github.com/RooCodeInc/Roo-Code)
- [Roo Code Documentation](https://docs.roocode.com/)

**Status:** ✅ Fully implemented with global and project-level support
└── CONTINUE.md                  # Consolidated reference from most .mdc files

./.ainish-coder/                 # Excluded from consolidation
├── anishinaabe-cyberpunk-style.md
├── prompt-security.md
├── critical.md
├── code-security.md
├── KNOWLEDGE_BASE.md
└── PRD.md
```

**Excluded from Consolidation:** (Same as Qwen/Gemini)
- `anishinaabe-cyberpunk-style.mdc`
- `prompt-security.mdc`
- `critical.mdc`
- `code-security.mdc`
- `KNOWLEDGE_BASE.mdc`
- `PRD.mdc`

**Notes:**
- `CONTINUE.md` serves as a reference document for AINISH guidelines
- Active configuration is managed via `config.yaml` (edit via Continue sidebar)
- User must configure Continue settings manually via the gear icon
- AINISH reference docs provide context for your project

---

### 7. MAI RULES ✅ **UNIVERSAL SYSTEM**

**Configuration Location:**
- **Primary:** `~/.mai-rules/MAIRULES.md` (universal rules for all tools)
- **Symbolic Link:** `./MAIRULES.md` (project-level reference)
- **File Format:** `.md` markdown
- **Command:** `ainish-coder --mairules`

**Purpose:**
Universal rule system created by ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ to standardize guidelines across ALL AI coding tools.

**What's Included:**
- Fact-Based Decision Making & Critical Thinking Framework
- Modern Prompting & Context Engineering (OOReDAct)
- Security Guidelines (Code & Prompt Security)
- Code Structure & Architecture Standards
- Python Package Management Best Practices
- Documentation Usage Guidelines
- Date/Time Verification Rules
- Cultural Integration (Optional Anishinaabe-Cyberpunk)
- License & Attribution Requirements
- Tool-Specific Adaptation Guide

**Deployment:**
```bash
ainish-coder --mairules
```

**Status:** ✅ **UNIVERSAL SYSTEM** - Works with all current and future AI tools

---

## Configuration Strategy Summary

### Deployment Levels

| Tool | Level | Config Location | Instructions Location |
|------|-------|----------------|----------------------|
| **Cursor AI** | Project | `./.cursor/rules/` | Same (`.mdc` files) |
| **VSCode Copilot** | Repository | N/A | `./.github/copilot-instructions.md` |
| **Copilot CLI** | User + Repo | `~/.config/config.json` | `./.github/copilot-instructions.md` |
| **Continue Dev** | User + Project | `~/.continue/config.yaml` | `~/.continue/CONTINUE.md` + `./.ainish-coder/*.md` |
| **Qwen AI** | User + Project | `~/.qwen/QWEN.md` | `./.ainish-coder/*.md` |
| **Gemini** | User + Project | `~/.gemini/GEMINI.md` | `./.ainish-coder/*.md` |

### File Format Strategy

| Tool | Config Format | Instructions Format |
|------|--------------|-------------------|
| **Cursor AI** | `.mdc` | `.mdc` |
| **VSCode Copilot** | N/A | `.md` |
| **Copilot CLI** | `.json` | `.md` |
| **Continue Dev** | `.yaml` (or `.json`) | `.md` |
| **Qwen AI** | `.md` | `.md` |
| **Gemini** | `.md` | `.md` |

### Consolidation Strategy

**Consolidated (Single File):**
- Qwen: `~/.qwen/QWEN.md`
- Gemini: `~/.gemini/GEMINI.md`
- VSCode: `./.github/copilot-instructions.md`

**Separate Files:**
- Cursor: All files in `./.cursor/rules/`
- Security files: Always separate for all tools
- Critical files: Always separate for all tools

**Hybrid:**
- Continue Dev: User config + project reference docs
- Copilot CLI: User config + repository instructions

---

## Implementation Checklist

### Current Status

All 6 major AI coding tools are now fully supported! ✅
Plus universal MAI RULES system! 🌟

- [x] Cursor AI (`.cursor/rules/`)
- [x] VSCode GitHub Copilot (`.github/copilot-instructions.md`)
- [x] GitHub Copilot CLI (uses VSCode structure)
- [x] Qwen AI (`~/.qwen/QWEN.md`)
- [x] Gemini (`~/.gemini/GEMINI.md`)
- [x] Continue Dev (`~/.continue/CONTINUE.md`)
- [x] **MAI RULES** (`~/.mai-rules/MAIRULES.md`) - Universal system!

### Implementation Complete! 🎉

**Continue Dev** has been successfully implemented with:

1. ✅ Created `deploy_continue_structured()` function in `ainish-setup.sh`
2. ✅ Generate CONTINUE.md consolidated reference document
3. ✅ Deploy separate security files to `./.ainish-coder/`
4. ✅ Add command alias: `ainish-coder --continue`
5. ✅ Updated all documentation (README.md, AI-TOOL-CONFIG-LOCATIONS.md, help text)
6. ✅ Added wrapper function support in shell config

**Deployment Command:**
```bash
ainish-coder --continue
```

**What Gets Deployed:**
- `~/.continue/CONTINUE.md` - Consolidated reference document
- `./.ainish-coder/*.md` - Separate security and critical files

---

## Testing Commands

### Verify Current Deployments
```bash
# Cursor AI
ls -la .cursor/rules/

# VSCode Copilot
ls -la .github/copilot-instructions.md
ls -la .github/instructions/

# Qwen
ls -la ~/.qwen/
ls -la .ainish-coder/

# Gemini
ls -la ~/.gemini/
ls -la .ainish-coder/

# Continue Dev
ls -la ~/.continue/
ls -la .ainish-coder/

# MAI RULES (universal)
ls -la ~/.mai-rules/
ls -la MAIRULES.md  # Symbolic link

# Continue Dev (manual check)
ls -la ~/.continue/
```

### Test Deployment Commands

```bash
# Deploy to Cursor
ainish-coder

# Deploy to VSCode Copilot
ainish-coder --vscode

# Deploy to Qwen
ainish-coder --qwen

# Deploy to Gemini
ainish-coder --gemini

# Deploy to Continue
ainish-coder --continue

# Deploy to Cline
ainish-coder --cline

# Deploy to Roo Code
ainish-coder --roocode

# Deploy MAI RULES (UNIVERSAL SYSTEM!)
ainish-coder --mairules

# Install global rules for all tools
ainish-coder --install-global
```

---

## Notes

1. **GitHub Copilot CLI** automatically reads repository instructions from `.github/copilot-instructions.md`, so no separate deployment needed beyond VSCode deployment.

2. **Security Strategy**: All tools keep security-related files separate:
   - `prompt-security.md`
   - `code-security.md`
   - `critical.md`
   - `KNOWLEDGE_BASE.md`
   - `PRD.md`

3. **File Format Evolution**:
   - Original: `.mdc` (Cursor-specific)
   - Standard: `.md` (universal markdown)
   - Config: `.yaml`/`.json` (structured data)

4. **Version Control**:
   - Project-level configs: Committed to repository
   - User-level configs: In home directory (not version controlled)

---

## References

- [GitHub Copilot Custom Instructions](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions)
- [GitHub Copilot CLI Documentation](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli)
- [Continue Configuration Guide](https://docs.continue.dev/customize/deep-dives/configuration)
- [Cursor AI Documentation](https://cursor.so/docs)

---

**Document Maintained By:** ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi)  
**Last Verified:** October 27, 2025
