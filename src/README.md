# src/ — AINISH-Coder Implementation Library

This directory contains the modular components of the AINISH-Coder system, organized following the **MAQ Design** pattern (Molecules ← Atoms ← Quanta).

## Directory Structure

```
src/
├── quanta/             # Core utilities and functions (no dependencies)
│   ├── backup.sh       # Backup/restore operations
│   ├── colors.sh       # ANSI color definitions
│   ├── config.sh       # Configuration utilities
│   ├── file_operations.sh  # File/directory manipulation
│   ├── file_utils.sh   # File utility helpers
│   ├── ignore_patterns.sh  # Ignore pattern management
│   ├── paths.sh        # Path configuration and constants
│   ├── sanitize-settings.sh # Secret sanitization utility
│   ├── secret-protection-help.sh # Secret protection help text
│   ├── security_scan.sh # Security scanning
│   └── validation.sh   # Validation functions
│
├── atoms/              # Feature modules (depend on quanta)
│   ├── clear_all_rules.sh  # Clear existing rules
│   ├── deploy_agents.sh    # Deploy agent configurations
│   ├── deploy_*.sh         # Tool-specific deployments
│   ├── setup-secret-protection.sh # Secret protection setup
│   ├── setup_shell.sh      # Shell wrapper setup
│   └── help.sh             # Help display
│
├── molecules/          # High-level orchestration (depend on atoms)
│   └── install.sh      # System-wide installation wrapper
│
├── templates/          # Deployable boilerplate templates
│   └── llms.txt        # User-project llms.txt template
│
└── pqc-secrets/        # Rust: FIPS 203 secrets manager (ML-KEM-768)
    ├── Cargo.toml
    ├── Cargo.lock
    └── src/
```

## Architecture

### Quanta (Fundamental Units)
**Purpose:** Smallest indivisible building blocks with no dependencies on other library components.

- **colors.sh**: ANSI color code definitions for terminal output
- **paths.sh**: Central configuration for all paths (repo, home directories, apps)
- **file_operations.sh**: Core file/directory operations (copy, mkdir, file discovery)
- **validation.sh**: Validation functions for paths, directories, configurations
- **backup.sh**: Backup creation, listing, and restoration
- **sanitize-settings.sh**: Remove API keys and secrets from configuration files
- **secret-protection-help.sh**: Display secret protection quick reference

### Atoms (Functional Units)
**Purpose:** Self-contained feature modules that compose quanta into deployment operations.

- **deploy_agents.sh**: Deploy AGENTS.md to target directories
- **deploy_skills.sh**: Deploy agent skill packs
- **help.sh**: Help text and usage display

### Molecules (Orchestrators)
**Purpose:** High-level orchestration that coordinates atoms into complete workflows.

- **install.sh**: System-wide installation wrapper
