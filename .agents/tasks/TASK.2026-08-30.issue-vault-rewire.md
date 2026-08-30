# TASK — Vault-First Issuance Rewiring (issue.rs → vault identity root)

- date: 2026-08-30
- branch: `feat/issue-vault-rewire` (worktree `../issue-vault-rewire`, from `main` @ `b930963`)
- plan: `e45d68f5-6713-454b-8a1b-9751eb9f31d8` (approved by operator)
- classification: Confidential — no secrets in this file (names + fingerprints only)

## Objective
Complete the vault-first discipline for the issuance provider (documented Phase-2
followup in `TASK.2026-08-30.pqc-issuance-transit.md`):

1. `issue <template> <name>` — when a vault exists and no explicit `PUB_PATH`
   is given: open the existing bundle **in-memory** under the vault identity
   (fail closed if the bundle recipient fingerprint ≠ vault identity), merge
   the minted key, re-seal for the vault EK, write atomically (tmp+rename,
   0600). Ends the fresh-bundle/`--force`-destroy footgun. Explicit `PUB_PATH`
   (foreign-recipient/cross-machine) and no-vault paths keep current semantics.
2. `envelope export` — vault identity ML-DSA-65 signing by default (verifiable
   against the vault header pin); `--use-keychain` keeps the legacy ad-hoc
   keychain signer. Wire format unchanged.
3. `envelope import` — vault ML-KEM-768 seed decapsulation by default
   (session-cached or passphrase); `--use-keychain` keeps the legacy keychain
   read. Verify-before-decapsulate gate unchanged.
4. Signed audit-chain records for issuance/envelope-export ops (names + fps
   only, never values).

## Invariants
- Wire formats byte-compatible (bundle v1, envelope v1, vault v1). No new
  crates. FIPS 203/204 primitives only + AES-256-GCM + Argon2id.
- No plaintext merge on disk; keychain untouched on vault paths.
- Live-store protection: every test/E2E runs in a sandboxed `PQC_CONFIG_DIR`
  with synthetic passphrase + sandbox `PQC_KEYCHAIN_ACCOUNT`; env set/unset in
  the same command block (2026-08-30 incident rule).
- Never print/log key or secret values.

## Gates (must pass before merge ask)
- [x] `cargo clippy --all-targets` 0 warnings
- [x] `cargo test` all green — 24/24 (20 existing + 4 new vault-first tests), 4.42s
- [x] `cargo audit` no new warnings (pre-existing allowed anyhow 1.0.102 advisory only)
- [x] Python engine `unittest discover` 14/14 (no regression), 4.41s
- [x] gitleaks clean — `git diff main | gitleaks stdin` exit 0, no leaks; whole-tree
      findings are pre-existing synthetic fixtures (SKILL.md §examples,
      test_vault_parity.py `VTEST_*`) + `target/` rmeta false positives, files
      untouched by this task
- [x] Sandboxed subprocess E2E — 13/13 stages (`/tmp/pqc-e2e-issue-vault.sh`,
      sandbox mktemp'd + removed, env set/unset inside one process, HOME pinned
      to sandbox so DEFAULT_BUNDLE expansion stays sandboxed, synthetic
      passphrase never printed, sandbox-prefixed keychain account): vault init →
      export-identity → issue wtf alpha (vault-fresh, 64-hex) → export value
      matches enrollment → issue wtf beta merge (no --force, both keys) →
      collision refusal → envelope export `[vault identity]` → envelope import
      roundtrip (sig verified) → tampered envelope ct fails closed → forged
      signer_pubkey fails closed → tampered bundle `vault verify` fails /
      restored bundle `verify OK` → `audit-verify OK` → bundle 0600 + ML-DSA-65
      sidecar shape
- [x] `bin/pqc-secrets.darwin-arm64` rebuilt + staged (1,539,120 B; wrapper
      header bumped to v1.2.0 {keygen, pack, export, issue, envelope, vault})
- [x] Docs: SKILL.md §5.9 vault-first behavior + §5.10 vault signer/seed +
      new §5.11 agent review surface, `src/README.md` vault-first issuance
      bullet, root `llms.txt` vault-first identity bullet (DOX pass), COMMS
      ledger update + intent-merge

## Decisions
- `vault_open_bundle` gates on the bundle's recipient fp vs the vault header
  pin BEFORE any decapsulation (clear error instead of raw KEM failure).
- Atomic 0600 write for all issuance-written bundles (merge + fresh vault
  path); legacy `cmd_pack` untouched (out of scope).
- Audit policy: mutating ops append (`issue`, `envelope-export`); read-only
  ops never append (consistent with `export` not auditing).
- Hub status: checked in via `wtf agent` bridge (only other agent idle on
  hub-upgrade in a separate worktree; no collision).
