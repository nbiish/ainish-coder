# AGENTS.md Compatibility Matrix

**Last Updated:** October 29, 2025  
**Standard Formalized:** August 2025

---

## Overview

`AGENTS.md` is the emerging universal standard for AI pair programmer instructions, formalized in August 2025 through collaboration between OpenAI, Google, Cursor, and Factory. Over 20,000 repositories on GitHub have adopted this standard.

---

## ✅ Native AGENTS.md Support

These tools read `AGENTS.md` directly from the project root without additional configuration:

| Tool | Status | Location | Notes |
|------|--------|----------|-------|
| **GitHub Copilot** | ✅ Native | `AGENTS.md` | Also supports `.github/copilot-instructions.md`, `CLAUDE.md`, `GEMINI.md` |
| **Cursor** | ✅ Native | `AGENTS.md` | Also has proprietary `.cursor/rules/` directory |
| **Gemini CLI** | ✅ Native | `AGENTS.md` | Mainstream coding assistant support |
| **OpenAI Codex** | ✅ Native | `AGENTS.md` | Part of standardization effort |
| **Aider** | ✅ Configurable | `AGENTS.md` | Traditionally used `CONVENTIONS.md` |
| **Factory** | ✅ Native | `AGENTS.md` | Involved in developing the standard |

---

## ⚠️ Workaround Support (Symbolic Linking)

These tools use proprietary formats but can consume `AGENTS.md` via symlinks:

| Tool | Proprietary Format | Workaround | Status |
|------|-------------------|------------|--------|
| **Continue.dev** | `.continue/rules/*.md` | Symlink `.continue/rules/AGENTS.md` → `AGENTS.md` | GitHub issue #6716 - support in progress |
| **Cline** | `.clinerules/*.md` | Symlink `.clinerules/AGENTS.md` → `AGENTS.md` | GitHub issue #5033 - requested feature |
| **Windsurf** | `.windsurf/rules/*.md` | Symlink `.windsurf/rules/rules.md` → `AGENTS.md` | Proprietary format |

---

## ❌ Proprietary Format Only

These tools require their own formats and don't support `AGENTS.md` natively:

| Tool | Format | Location | Deployment Strategy |
|------|--------|----------|---------------------|
| **RooCode** | `.roo/*.md` | `.roo/` directory | Copy MAIRULES.md to `.roo/` |
| **Qwen** | Custom files | `QWEN.md` | Create custom QWEN.md file |
| **Claude Code** | `CLAUDE.md` | Project root | Can redirect to AGENTS.md with "See @AGENTS.md" |

---

## 🔄 Deployment Strategies

### Strategy 1: AGENTS.md First (Recommended)

```bash
# 1. Create AGENTS.md as single source of truth
ainish-coder --agents

# 2. Deploy tool-specific configurations (they'll symlink to AGENTS.md)
ainish-coder --copilot    # Symlinks .github/copilot-instructions.md → AGENTS.md
ainish-coder --cline      # Symlinks .clinerules/AGENTS.md → AGENTS.md
ainish-coder --windsurf   # Symlinks .windsurf/rules/rules.md → AGENTS.md
ainish-coder --cn         # Symlinks .continue/rules/AGENTS.md → AGENTS.md
ainish-coder --gemini     # Symlinks GEMINI.md → AGENTS.md

# 3. Tools with proprietary formats get copies
ainish-coder --roocode    # Copies to .roo/
ainish-coder --qwen       # Creates QWEN.md
```

### Strategy 2: Legacy MAIRULES.md

```bash
# For projects that prefer MAIRULES.md naming
ainish-coder --mairules   # Creates MAIRULES.md in current directory
```

### Strategy 3: Hierarchical Configuration

```
project/
├── AGENTS.md                          # Universal standard (highest priority)
├── .github/
│   └── copilot-instructions.md       # Symlink → ../AGENTS.md
├── .continue/
│   └── rules/
│       └── AGENTS.md                 # Symlink → ../../AGENTS.md
├── .clinerules/
│   └── AGENTS.md                     # Symlink → ../AGENTS.md
├── .windsurf/
│   └── rules/
│       └── rules.md                  # Symlink → ../../AGENTS.md
├── .roo/
│   └── MAIRULES.md                   # Copy (proprietary format)
├── GEMINI.md                         # Symlink → AGENTS.md
└── QWEN.md                           # Copy (custom format)
```

---

## 📋 Tool-Specific Notes

### GitHub Copilot
- **Native AGENTS.md support** as of August 2025
- Also checks: `.github/copilot-instructions.md`, `.github/instructions/**.instructions.md`
- Supports: `CLAUDE.md`, `GEMINI.md` for backward compatibility
- **Deployment**: Symlink `.github/copilot-instructions.md` → `AGENTS.md`

### Continue.dev (cn)
- GitHub issue #6716 (July 2025) requesting native AGENTS.md support
- Currently uses `.continue/rules/` directory with Markdown or YAML files
- **Deployment**: Symlink `.continue/rules/AGENTS.md` → `../../AGENTS.md`

### Cline
- GitHub issue #5033 requesting native AGENTS.md support
- Currently uses `.clinerules/` directory
- **Deployment**: Symlink `.clinerules/AGENTS.md` → `../AGENTS.md`

### Windsurf
- Uses `.windsurf/rules/` for granular rules
- Supports always-on rules, @mention-able rules, and file glob attachments
- **Deployment**: Symlink `.windsurf/rules/rules.md` → `../../AGENTS.md`

### Cursor
- **Native AGENTS.md support**
- Also has proprietary `.cursor/rules/` directory
- Can use both simultaneously

### Gemini CLI
- **Native AGENTS.md support** confirmed
- Part of mainstream coding assistants
- **Deployment**: Symlink `GEMINI.md` → `AGENTS.md` for backward compatibility

### RooCode
- Uses `.roo/` directory structure
- Updated to conform to latest custom prompt syntax
- **Deployment**: Copy MAIRULES.md to `.roo/` (no symlink support)

### Qwen
- Based on Gemini CLI architecture
- Likely supports AGENTS.md but not explicitly confirmed
- **Deployment**: Create custom `QWEN.md` file

### Claude Code
- Uses `CLAUDE.md` files (can be hierarchical)
- **Workaround**: Create `CLAUDE.md` with content: "See @AGENTS.md"
- Supports hierarchical structure with closest file taking precedence

---

## 🎯 Best Practices

### Multi-Tool Projects

1. **Use AGENTS.md as single source of truth**
2. **Symlink tool-specific files to AGENTS.md**
3. **Copy only for tools without symlink support**
4. **Keep AGENTS.md at project root**

### Hierarchical Organization

- Both `AGENTS.md` and `CLAUDE.md` support hierarchical structures
- Can have root-level file and nested files in subdirectories
- Package-specific or module-specific instructions possible
- Closest file to code being edited takes precedence

### Testing Configuration

Ask your AI tool:
```
"What custom instructions or context files are you currently using for this project?"
```

This verifies which files are being loaded. Claude and Cursor are more transparent about this.

---

## 📊 Adoption Statistics

- **20,000+** GitHub repositories using AGENTS.md (as of October 2025)
- **Formalized:** August 2025
- **Contributors:** OpenAI, Google, Cursor, Factory, and community

---

## 🔗 References

- [AGENTS.md Official Site](https://agents.md)
- [Factory Documentation](https://docs.factory.ai/cli/configuration/agents-md)
- [Cursor Documentation](https://cursor.com/docs/context/rules)
- [VS Code Custom Instructions](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)
- [Continue.dev Issue #6716](https://github.com/continuedev/continue/issues/6716)
- [Cline Issue #5033](https://github.com/cline/cline/issues/5033)

---

## 📜 License & Attribution

**Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi)**  
Also known legally as JUSTIN PAUL KENWABIKISE  
Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder)  
Descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band  
Enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians

**License:** https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/working-LICENSE
