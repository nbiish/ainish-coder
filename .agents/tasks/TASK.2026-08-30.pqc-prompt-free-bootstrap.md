# TASK.2026-08-30.pqc-prompt-free-bootstrap

Prompt-free PQC access for agents. One passphrase entry at setup, never per-run.

## Context
- Vault-first migration made every `export`/`list` prompt for the vault passphrase.
- omp (and any tooling) hit the prompt via secrets-load wrappers each run.
- Operator mandate: easy + secure agent access; enter once at system setup;
  survives skill/engine iterations.

## Design (chain-of-draft)
- Bundle keeps `VAULT_PASSPHRASE` entry (existing pattern, SKILL.md appendix).
- Keychain decap works without the vault (same identity seed).
- Wrapper bootstrap: vault locked + no env → keychain decap → if bundle
  carries VAULT_PASSPHRASE → unlock session holder (--ttl, default 8h) →
  rerun vault-first command. Keychain fail → interactive prompt (unchanged).
- Applies to: rust `export`/`issue`/`envelope`/`vault *` (session-gated) and
  python identity reads (`verify`/`list`/`rename`) via PQC_VAULT_PASSPHRASE env.
- Passphrase only ever transits memory/env of one command; never disk/logs.

#### worktree + comms checkin
#### wrapper bootstrap hook (bin/pqc-secrets)
#### docs: SKILL.md section + llms.txt bullet + src/README.md
#### gates: bash -n, shellcheck, gitleaks
#### verify: locked-vault prompt-free export + list from worktree
#### intent-merge (await user confirm)
