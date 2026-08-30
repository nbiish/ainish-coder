# src/ — AINISH-Coder Implementation

This directory contains the shell components used by the CLI. Components are kept directly under `src/` so their names and dependencies are easy to discover.

## Directory Structure

```text
src/
├── *.sh                # CLI utilities and deployment commands
├── templates/          # Deployable, repository-agnostic templates
│   ├── llms.txt        # User-project llms.txt template
│   └── AGENTS.COMMS.md # Agent Communication System protocol template
│                      # (deployed as AGENTS/{date}.COMMS.md by --rules;
│                      #  merge-safe — agent entry blocks are preserved)
│
└── pqc-secrets/        # Rust: FIPS 203 secrets manager (ML-KEM-768, v1.1.0 seed-form aware)
    ├── Cargo.toml
    ├── Cargo.lock
    └── src/
```

## Components

- Shared utilities provide paths, validation, file operations, backups, and security checks.
- Deployment commands provide agent, skill, configuration, and documentation workflows.
- `bin/ainish-coder` is the single CLI entrypoint and sources the components it needs.

## pqc-secrets engine notes

- **`rust-fips203`-tagged bundles are NOT final-FIPS-203 interoperable** (fips203
  0.4.3 bug): bundles packed by the v1.0.0 Rust binary can only be decapsulated by
  that same fips203 0.4.3 engine — not by final-FIPS-203 implementations, including
  the canonical Python engine and the v1.1.x Rust engine (RustCrypto `ml-kem`).
  Migrate before use with v1.1.x engines: export with the **v1.0.0 binary**, then
  **re-pack with the Python engine**.
- Export shell-quoting is byte-identical across engines (POSIX single-quote wrap,
  embedded `'` → `'\''`), so `eval "$(pqc-secrets export)"` is safe for any value.
  Verified by `.agents/skills/pqc-secrets/tests/test_export_quoting.py`.
