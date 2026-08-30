# TASK.2026-08-30.pqc-vault-core

parent: oz-orchestrator | plan: 25cbca24-4a1b-49e2-9e08-fd917f78d05d (Phase 1)
branch: feat/pqc-vault-core | wt: /Users/nbiish/code/pqc-vault-core | base: main @ f28c6a8
classification: Confidential (inherits all security rules; no secrets herein)

#### Draft: orientation
llms.txt read (PRD anchor). COMMS ledgers read (durable + live).
fips203-0.4.3 non-interop noted; live identity = final-FIPS seed-form.
Incident mandate: live store + keychain are PRODUCTION; sandbox env only.

#### Draft: objective
OS-independent vault: no OS keychain reliance, self-contained PQC at rest.
`vault` subcommand family + `vault.pqc` (0600) store in config dir.

#### Draft: format decisions
- Root identity: ML-KEM-768 64-byte d||z seed, AES-256-GCM-wrapped under
  Argon2id(passphrase, 16B salt, m=65536 KiB t=3 p=4, 32B out) KEK.
  Params match SKILL.md §4 Argon2id row (stronger than OWASP-2025 minimums).
- ML-DSA-65 signing keypair wrapped at rest. FIPS 204 seed (xi) is 32 bytes
  per spec + RustCrypto ml-dsa 0.1.1 (`Seed` = B32); directive said 64-byte —
  implemented the spec-correct 32-byte xi, deviation documented + reported.
- Public material stored clear in header: expanded EK sha3-256 fp + DSA vk
  (1952B b64) + vk fp — enables keychain-free `verify`/`audit-verify`.
- AADs: pqc-secrets:vault:v1:{kem-seed,dsa-seed}. Version: 1.
- Audit chain: CHAIN1 JSON lines appended to audit.log; each record =
  prev_hash + ts + seq + action + detail, this_hash = SHA3-256 over canonical
  concatenation, signed ML-DSA-65 (deterministic, empty ctx). All records
  signed; verify ops are read-only (no unsigned records exist).

#### Draft: session cache
`vault unlock` spawns hidden `_vault-holder` child; KEK passed via stdin
pipe (never argv/env/disk); Unix-socket JSON protocol in 0700 dir;
TTL default 900s (--ttl, --no-cache stateless). Holder zeroizes on
lock/TTL/drop. Seeds cross the socket only as in-memory hex (same-uid IPC).
POSIX-only session; --no-cache is the portable path.

#### Draft: keychain demotion
vault exists -> canonical root. `export` prefers vault (prompt/session).
`keygen` refuses when vault exists unless --use-keychain (fail closed).
No vault -> byte-identical legacy behavior (backward compat gate).
`vault migrate` = one-time keychain->vault move; NEVER deletes keychain;
rollback gates: wrap -> re-read -> fingerprint before==after, else unlink.

#### Draft: python parity
pqc_secrets.py export: if vault.pqc exists, unwrap identity via
argon2-cffi (pinned) + cryptography AESGCM; else legacy store/keychain.
ML-KEM path only; audit chain verify is Rust-side (no mature pinned
Python ML-DSA). Decision documented in SKILL.md.

#### Draft: sandbox law
Tests: temp PQC_CONFIG_DIR + PQC_KEYCHAIN_ACCOUNT=pqc-secrets-vtest-vault +
PQC_VAULT_PASSPHRASE synthetic; env never outlives a command block;
subprocess-only engine invocations; fingerprints only in output.
Test KDF lightener PQC_VAULT_TEST_KDF_LIGHT=1 (test env only; params live
in vault header; production default stays 64MiB/t3/p4).

#### Gates (receipts, 2026-08-30T15:39Z)
- cargo clippy --all-targets: CLEAN (0 warnings)
- cargo test: 11 passed, 0 failed (4 existing + 7 vault)
- cargo build --release: OK
- cargo audit: 1 allowed warning (anyhow, pre-existing) — no NEW warnings
- stage bin/pqc-secrets.darwin-arm64: DONE (restaged after holder-routing fix)
- sandboxed E2E: PASS — temp PQC_CONFIG_DIR, env never exported: init/status/
  unlock ttl=2m (session live, status shows TTL)/unlock --no-cache/sign/verify/
  tamper fail-closed (rc=1)/restore verify/audit-verify (4 signed recs)/lock
  (zeroize)/status locked/lock-again no-session/migrate --dry-run (vault
  byte-identical, untouched)
- python parity: test_vault_parity.py 5/5 OK (rust init → export-identity → py
  pack → py export via vault, no keychain; wrong-passphrase fail-closed; 0600
  shape); phase-0 test_export_quoting.py 9/9 OK (no regression)
- Bug found+fixed during E2E: hidden `_vault-holder` child was unrouted at the
  top-level arg match in main() → "holder exited immediately". Fixed: top-level
  arm `vault::HOLDER_ARG => vault::dispatch(&args[1..])` + pub(crate) const.
- Deviation from directive (documented): FIPS 204 ML-DSA seed (ξ) is 32 bytes
  per spec + ml-dsa 0.1.1 API; the directive's "64-byte ML-DSA seed" is the
  ML-KEM (FIPS 203) convention. Implemented 32-byte ξ; reported to orchestrator.

#### Notes
- bin/pqc-secrets dispatcher is NOT in owned-file list: `vault)` routing
  line proposed to orchestrator in completion report (1-line patch).
