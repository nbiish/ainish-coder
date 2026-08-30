# TASK.2026-08-30.vault-session-until-shutdown

Vault session persists until shutdown — no wall-clock expiry.

## Context
- Operator: vault access stays accessible+secured until machine restarts or
  shuts down; persist indefinitely, even through sleep; agentic tooling and
  AI cron systems need always-on access once set up.
- Prior state: bootstrap unlocked with 8h TTL — expiry mid-flight breaks
  long-running agents/cron.

## Design (chain-of-draft)
- `NO_EXPIRY = u64::MAX` sentinel; `vault unlock --ttl never`.
- Holder skips deadline when never; status reports "until lock/shutdown".
- Sleep-safe: Instant pauses during sleep; never-mode wall-clock independent.
- Engine default stays 15m; wrapper default PQC_UNLOCK_TTL → never.
- Security unchanged: KEK memory-only, 0700 socket, zeroize on lock/drop,
  signed audit `ttl=never` + `vault lock` still instant.
- v1.2.1; rebuild darwin-arm64 binary; docs (SKILL §5.12, env table,
  README, llms.txt); zshrc machine config → never.

#### worktree + comms checkin
#### rust: sentinel + holder + parse + status + tests
#### wrapper default never + version v1.2.1 + docs
#### cargo test (25 pass) + rebuild + gates
#### verify: locked vault → prompt-free export; status shows no-TTL
#### intent-merge (await user confirm)
