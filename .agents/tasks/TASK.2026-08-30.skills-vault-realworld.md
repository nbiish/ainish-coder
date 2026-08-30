# TASK.2026-08-30 — pqc-skills vault real-world update

- **Branch:** `docs/pqc-skills-vault-realworld` (worktree `../ainish-skills-vault-realworld`, from main @ 09238b9)
- **Objective:** Update the `pqc-secrets` skill source (SKILL.md) so it reflects the as-executed v1.2.0 vault realities observed in the 2026-08-30 live migration (betterbrowsermcp session).
- **Driver:** User directive — "update the PQC Secrets Skills Source directory so that it is fully updated with real world use cases and needs" (prerequisite to multi-tab agent coordination work).

## Inputs (live-verified 2026-08-30, ~20:10–20:26Z)

1. Keychain → vault migration ceremony executed end-to-end on the live store:
   dry-run → passphrase staged into the bundle as `VAULT_PASSPHRASE` via
   `browser_secrets_add` (env-var lane; clipboard lane fails on background
   tabs) → `vault migrate` under `PQC_VAULT_PASSPHRASE` → `vault unlock
   --ttl 15m` → `vault status` / `vault audit-verify` / `verify` / `list` all green.
2. Engine/session asymmetry (the actual failure we hit): Python engine
   (`verify`, `list`) is vault-first and reads ONLY `PQC_VAULT_PASSPHRASE`
   (no session-holder support); Rust native (`export`, `vault *`) uses the
   `_vault-holder` session first. Per-command env prefixes (`VAR=x cmd1 &&
   cmd2`) left `verify` without the var → interactive prompt → empty
   passphrase → fail-closed error.
3. Session lifecycle: TTL 15 m default, remaining shown by `vault status`;
   expiry removes the socket; daemons (browser hub) spawning `pqc export`
   need a live session (or env var) — expiry silently breaks secret ops.
4. Passphrase recovery circularity: storing `VAULT_PASSPHRASE` inside the
   bundle is only readable while a session is unlocked (or passphrase
   known) → operator must record the passphrase externally too.
5. Keychain retention: `vault migrate` never touches the keychain entry;
   manual `security delete-generic-password` only after operator confirm.

## Deliverables (SKILL.md only — docs task, no code)

- §2.1: identity-source matrix (session / env / passphrase-free) + session lifecycle.
- §4: `PQC_VAULT_PASSPHRASE` in the env-var list.
- §7: vault-mode daemon recipe (headless re-unlock, `browser_secrets_status` diagnosis).
- §10.4: keychain → vault migration ceremony (as executed).
- §10.5: lost-vault-passphrase disaster recovery + circularity warning.

## Constraints

- No secret values, no real passphrase material — placeholders only.
- Commit in worktree; merge to main only after user confirmation.
- gitleaks clean before commit.
