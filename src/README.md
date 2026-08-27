# src/ — AINISH-Coder Implementation

This directory contains the shell components used by the CLI. Components are kept directly under `src/` so their names and dependencies are easy to discover.

## Directory Structure

```text
src/
├── *.sh                # CLI utilities and deployment commands
├── templates/          # Deployable, repository-agnostic templates
│   └── llms.txt        # User-project llms.txt template
│
└── pqc-secrets/        # Rust: FIPS 203 secrets manager (ML-KEM-768)
    ├── Cargo.toml
    ├── Cargo.lock
    └── src/
```

## Components

- Shared utilities provide paths, validation, file operations, backups, and security checks.
- Deployment commands provide agent, skill, configuration, and documentation workflows.
- `bin/ainish-coder` is the single CLI entrypoint and sources the components it needs.
