# population/ - AINISH-Coder Implementation Library

This directory contains the modular components of the AINISH-Coder system, organized following the **Atomic Design** pattern (Atoms → Molecules → Organisms).

## Directory Structure

```
population/
├── atoms/              # Core utilities and functions (no dependencies)
│   ├── backup.sh       # Backup/restore operations
│   ├── colors.sh       # ANSI color definitions
│   ├── config.sh       # Configuration utilities
│   ├── file_operations.sh  # File/directory manipulation
│   ├── file_utils.sh   # File utility helpers
│   ├── ignore_patterns.sh  # Ignore pattern management
│   ├── paths.sh        # Path configuration and constants
│   ├── sanitize-settings.sh # Secret sanitization utility
│   ├── secret-protection-help.sh # Secret protection help text
│   └── validation.sh   # Validation functions
│
├── molecules/          # Feature modules (depend on atoms)
│   ├── clear_all_rules.sh  # Clear existing rules
│   ├── deploy_agents.sh    # Deploy agent configurations
│   ├── deploy_*.sh         # Tool-specific deployments (cursor, windsurf, etc.)
│   ├── github-settings-guide.sh  # GitHub Actions setup guide
│   ├── setup-secret-protection.sh # Secret protection setup
│   ├── test-github-actions.sh    # GitHub Actions testing
│   ├── setup_shell.sh      # Shell wrapper setup
│   └── help.sh             # Help display
│
└── organisms/          # High-level orchestration
    └── install.sh      # System-wide installation wrapper
```

## Architecture

### Atoms (Core Functions)
**Purpose:** Fundamental building blocks with no dependencies on other library components.

- **colors.sh**: ANSI color code definitions for terminal output
- **paths.sh**: Central configuration for all paths (repo, home directories, apps)
- **file_operations.sh**: Core file/directory operations (copy, mkdir, file discovery)
- **validation.sh**: Validation functions for paths, directories, configurations
- **backup.sh**: Backup creation, listing, and restoration
- **sanitize-settings.sh**: Remove API keys and secrets from configuration files
- **secret-protection-help.sh**: Display secret protection quick reference


````

