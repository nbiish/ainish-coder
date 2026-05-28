# TASK 2026-05-28

- **Objective:** Integrate native Rust PQC secrets manager under `src/pqc-secrets/` and `bin/pqc-secrets`.
- **Status:** Completed
- **PQC Flag:** Enforced (FIPS 203/204/205 only for secrets management, no plaintext keys)

## Draft Steps
1. Create `src/pqc-secrets/Cargo.toml`
2. Write `src/pqc-secrets/src/main.rs`
3. Compile release build
4. Strip and copy binary to `bin/pqc-secrets`
5. Update docs in `AGENTS.md`
6. Verify and commit
