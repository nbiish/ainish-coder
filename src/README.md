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
└── pqc-secrets/        # Rust: FIPS 203/204 secrets manager (v1.2.0: ML-KEM-768 seed-form + ML-DSA-65 vault core)
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
- **v1.2.0 (2026-08-30) — `vault` subcommand family (`src/pqc-secrets/src/vault.rs`):**
  OS-independent, passphrase-wrapped identity vault at `~/.config/pqc-secrets/vault.pqc`
  (0600). Argon2id(m=64 MiB, t=3, p=4) → 32-byte vault KEK → AES-256-GCM wraps a
  fresh ML-KEM-768 seed (64 B d‖z) + ML-DSA-65 seed (32 B ξ); AAD-pinned blobs fail
  closed; seeds live only in `Zeroizing` memory. When a vault exists it is the
  canonical identity root: `keygen` refuses (opt-in `--use-keychain`) and `export`
  decapsulates via the vault — no OS keychain involved. `vault migrate` adopts the
  keychain identity one-time with byte-roundtrip rollback gates and never touches
  keychain material. `vault sign`/`verify` are ML-DSA-65 detached (verify needs no
  passphrase); the audit log becomes a hash chain of ML-DSA-65-signed records
  (`vault audit-verify` replays). Session cache (default 15 min TTL, `--ttl`,
  `--no-cache`) keeps the KEK only in a hidden child's memory (stdin pipe + 0700
  Unix socket); `--no-cache` is the portable path. Python parity (read-side, ML-KEM
  identity only): `pqc_secrets.py` unwraps the vault seed via pinned
  `argon2-cffi==25.1.0` — ML-DSA/audit-verify stays Rust-only. Verified by
  `cargo test` (11 tests) + `.agents/skills/pqc-secrets/tests/test_vault_parity.py`.
- The engine also implements `issue <template> <name>` (device-key
  issuance; `wtf` builtin mints a 64-hex CSPRNG key, packs `WTF_<NAME>_SECRET`
  through the pack path, prints the quoted eval line + wtf enrollment JSON) and
  `envelope export|import` (cross-machine transfer: ML-KEM-768-wrapped
  AES-256-GCM payload signed with ML-DSA-65 via RustCrypto `ml-dsa` 0.1.1;
  import verifies the signature **before** decapsulation, fail closed).
  Issuance currently writes through the existing bundle path; it is rewired
  through the vault (Phase 1) at integration. Any transit endpoint must sit
  behind an overlay/TLS proxy — never plain HTTP to the public internet;
  future daemons target TLS 1.3 with hybrid `X25519MLKEM768`.
