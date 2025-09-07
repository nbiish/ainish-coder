# PRODUCT REQUIREMENTS DOCUMENT: ainish-coder

**Author:** ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish-Justin Waabanimikii-Kenwabikise) | **Date:** 2025-01-27 | **Version:** 1.1.0

## 1. OBJECTIVE

**Purpose:** ainish-coder is a comprehensive configuration manager for AI coding assistants that provides seamless setup and integration for multiple AI development tools in projects. It embodies Indigenous intellectual property principles while maintaining technical excellence through a unique Anishinaabe-Cyberpunk styling approach.

## 2. ARCHITECTURE

### Component Structure (Atom → Molecule → Matter)

**Atoms:** functions | variables | constants | packages
- Configuration files (.mdc/.md formats)
- Shell scripts and wrapper functions
- Git ignore rules and GitHub configurations
- Data tracking capabilities

**Molecules:** classes | modules
- ainish-setup.sh (main setup script)
- Triple deployment system (core, markdown, vscode)
- Structured VSCode distribution system
- MCP usage tracking system

**Matter:** main entry point
- ainish-coder wrapper command
- Unified configuration management
- Cross-platform compatibility

## 3. FUNCTIONAL REQUIREMENTS

### Core Features
- Unified setup script for all AI coding assistants
- Triple deployment system (core configurations, markdown format, VSCode/Copilot)
- Multiple AI tool support (GitHub Copilot, Cursor AI, VSCode)
- Flexible file format support (.mdc and .md)
- Automatic configuration with Gitignore rules
- Wrapper functions for convenient deployment
- MCP usage tracking and data storage
- Product Requirements Documentation

### User Experience
- One-command installation and setup
- Cross-platform compatibility (macOS, Linux, Windows)
- Clear documentation with Anishinaabe cultural elements
- Support for multiple shell environments
- Comprehensive troubleshooting guides

## 4. KNOWLEDGE BASE

**Documentation Structure:**
- `PRD.md` - Product Requirements Document
- `README.md` - Comprehensive user guide with scholarly citation
- `LICENSE` - Comprehensive restricted use license with tribal sovereignty protections
- `CONTRIBUTING.md` - Contributing guidelines
- `RULES_WE_WANT/` - Source configuration files
- `AINISH-DATA/` - MCP usage tracking and data storage

## 1. EXAMPLES

1. ```ainish-coder``` distributes the `.ainish-coder/` directory where it is called.

```bash
.ainish-coder/
⮑ *.mdc
⮑ .gitignore
⮑ .cursorignore
⮑ .cursorindexignore
⮑ .github/
    ⮑ FUNDING.yml
```

2. ```ainish-coder --vscode``` distributes the `.ainish-coder/` directory where it is called.

```bash
.ainish-coder/
⮑ copilot-instructions.md # (*.mdc appended into this directory -> !{certain.mdc} files)
⮑ .gitignore
⮑ .copilotignore
⮑ .copilotindexignore
⮑ .github/
    ⮑ FUNDING.yml
    ⮑ instructions/  # if a file is listed here is MUST NOT be appended into copilot-instructions.md
        ⮑ ainishinaabe-cyberpunk-style.instructions.md
        ⮑ prompt-security.instructions.md
        ⮑ critical.instructions.md
        ⮑ code-security.instructions.md
        ⮑ KNOWLEDGE_BASE.instructions.md
        ⮑ PRD.instructions.md
```

3. ```ainish-coder --markdown``` distributes the `.ainish-coder/` directory where it is called.

```bash
.ainish-coder/
⮑ cp ../*.mdc *.md
⮑ .gitignore
⮑ .github/
    ⮑ FUNDING.yml
```

4. ```ainish-coder --qwen``` distribution below:

```bash
~/.qwen/QWEN.md # -> (append all *.mdc this file QWEN.md !{certain.mdc} files)
# !{certain.mdc} files: MUST NOT be appended into QWEN.md
# .ainish-coder/
# ⮑ ainishinaabe-cyberpunk-style.md
# ⮑ prompt-security.md
# ⮑ critical.md
# ⮑ code-security.md
# ⮑ KNOWLEDGE_BASE.md
# ⮑ PRD.md
```

5. ```ainish-coder --gemini``` distribution below:

```bash
~/.gemini/GEMINI.md # -> (append all *.mdc this file GEMINI.md !{certain.mdc} files)
# !{certain.mdc} files: MUST NOT be appended into GEMINI.md
# .ainish-coder/
# ⮑ ainishinaabe-cyberpunk-style.md
# ⮑ prompt-security.md
# ⮑ critical.md
# ⮑ code-security.md
# ⮑ KNOWLEDGE_BASE.md
# ⮑ PRD.md
```

6. ```ainish-coder --style``` distributes the `ainishinaabe-cyberpunk-style.mdc` as a .md file in the current directory.

```bash
ainishinaabe-cyberpunk-style.md
```

7. ```ainish-coder --security``` distributes the `prompt-security.mdc` & `code-security.mdc` as a .md file in the current directory.

```bash
prompt-security.md
code-security.md
critical.md
```

8. ```ainish-coder --license``` distributes the `critical.mdc` as a .md file in the current directory.

```bash
critical.md
```

9. ```ainish-coder --instructions``` distributes the `.ainish-coder/` directory where it is called.

```bash
.ainish-coder/
⮑ ainishinaabe-cyberpunk-style.md
⮑ prompt-security.md
⮑ critical.md
⮑ code-security.md
⮑ KNOWLEDGE_BASE.md
⮑ PRD.md
```

10. ```ainish-coder --help``` displays the help message.

```bash
Usage: ainish-coder [options]
Options:
  --vscode        Distribute for VSCode Copilot
  --markdown      Distribute as Markdown files
  --qwen          Distribute for QWEN
  --gemini        Distribute for Gemini
  --style         Distribute Ainshinaabe Cyberpunk Style Guide
  --security      Distribute Prompt & Code Security Guidelines
  --instructions  Distribute Instructions
  --license       Distribute Critical Reminders
  --help          Display this help message
```

## 2. Setup Instructions

All file copies from commands are pulled from the repository our setup script is ran in.
