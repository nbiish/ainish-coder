# lib/ - AINISH-Coder Library

This directory contains the modular components of the AINISH-Coder system, organized following the **Atom → Molecule → Matter** architecture pattern defined in `structure.mdc`.

## Directory Structure

```
lib/
├── atoms/              # Core functions and constants
│   ├── colors.sh       # ANSI color definitions
│   ├── paths.sh        # Path configuration and constants
│   ├── file_operations.sh  # File/directory manipulation
│   ├── validation.sh   # Validation functions
│   └── backup.sh       # Backup/restore operations
│
├── molecules/          # Feature modules (depend on atoms)
│   ├── deploy_core.sh         # Core .mdc deployment
│   ├── deploy_markdown.sh     # Markdown (.md) deployment
│   ├── deploy_vscode.sh       # VSCode/Copilot deployment
│   ├── deploy_consolidated.sh # Shared consolidation logic
│   ├── deploy_gemini.sh       # Gemini AI deployment
│   ├── deploy_qwen.sh         # Qwen AI deployment
│   ├── deploy_continue.sh     # Continue Dev deployment
│   ├── deploy_mairules.sh     # MAI RULES deployment
│   ├── deploy_style.sh        # Style guide deployment
│   ├── deploy_security.sh     # Security files deployment
│   ├── deploy_instructions.sh # Instructions deployment
│   ├── deploy_license.sh      # License deployment
│   ├── setup_shell.sh         # Shell wrapper setup
│   └── help.sh                # Help display
│
└── matter/             # (Reserved for future main orchestrators)
```

## Architecture

### Atoms (Core Functions)
**Purpose:** Fundamental building blocks with no dependencies on other library components.

- **colors.sh**: ANSI color code definitions for terminal output
- **paths.sh**: Central configuration for all paths (repo, home directories, apps)
- **file_operations.sh**: Core file/directory operations (copy, mkdir, file discovery)
- **validation.sh**: Validation functions for paths, directories, configurations
- **backup.sh**: Backup creation, listing, and restoration

