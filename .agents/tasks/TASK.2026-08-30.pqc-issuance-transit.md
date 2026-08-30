# TASK.2026-08-30.pqc-issuance-transit

parent: oz-orchestrator
plan: 25cbca24-4a1b-49e2-9e08-fd917f78d05d (Phase 2 prep)
branch: feat/pqc-issuance-transit
worktree: /Users/nbiish/code/pqc-issuance-transit (from main f28c6a8)
classification: Confidential — no secret material in this file, ever.

## Contract

- llms.txt read (root). DOX chain walked: src/ → src/README.md. No child llms.txt under .agents/ or src/pqc-secrets/.
- Production live store `~/.config/pqc-secrets/` and keychain account `pqc-secrets-key` are OFF-LIMITS.
- Tests: in-memory only, synthetic keys, explicit tmp paths, sandbox account `pqc-secrets-vtest-issue`, prefix-form env only (never exported), engine via subprocess only.
- No push. No merge. Operator gates via orchestrator.

## Chain of Draft

- Read llms.txt, COMMS. Done.
- Check in both ledgers. Done.
- Read skills: wtf §2 JSON shape. Done.
- Check crates.io ml-dsa. Done.
- Pin ml-dsa 0.1.1 + zeroize. Done.
- Design envelope: versioned JSON, sig-first import. Done.
- issue wtf: mint 64-hex, seal pack-path, eval line + JSON. Done.
- Vault note: rewires at Phase 1. In code + SKILL.
- Transit note: overlay/TLS proxy mandatory; future daemons TLS 1.3 hybrid X25519MLKEM768. In SKILL.

#### Artifacts

- src/pqc-secrets/src/issue.rs — new; all issue/envelope logic + tests
- src/pqc-secrets/src/main.rs — minimal hook: mod, one match arm, pub(crate) visibility, usage line
- src/pqc-secrets/Cargo.toml — ml-dsa pin
- .agents/skills/pqc-secrets/SKILL.md — §5 issue/envelope + transit guidance
- .agents/skills/wtf-agent-hub/SKILL.md — §2 pointer
- src/README.md — engine notes
- bin/pqc-secrets.darwin-arm64 — staged release binary
- AGENTS/2026-08-30.COMMS.md — durable entries (committed via this branch)

## Envelope Format (v1)

```json
{
  "version": 1,
  "alg": "ML-KEM-768+ML-DSA-65",
  "recipient_key_sha3_256": "<hex sha3-256 of recipient ML-KEM-768 EK>",
  "signer_pubkey": "<b64 of 1952-byte ML-DSA-65 encoded verifying key>",
  "sig": "<b64 of ML-DSA-65 signature over signed payload>",
  "kem_ct_b64": "<b64 1088-byte ML-KEM ciphertext>",
  "nonce_b64": "<b64 12-byte AES-GCM nonce>",
  "ct_b64": "<b64 AES-256-GCM(PayloadSection JSON)>"
}
```

- Payload AAD: `pqc-secrets:v1:envelope:data`. Signature domain: `pqc-secrets:v1:envelope:sig` (prefixed to signed bytes; version LE + alg + recipient fp + kem_ct + nonce + ct follow).
- Import verifies ML-DSA-65 signature BEFORE decapsulation. Any mismatch → fail closed.
- Signing key: keychain service `pqc-secrets`, account `<PQC_KEYCHAIN_ACCOUNT|-default>-mldsa65`, 32-byte seed stored hex. Auto-provisioned on first export; fingerprint (sha3-256 of VK, 16 hex) to stderr — never the key.

## issue wtf

- `pqc-secrets issue wtf <name> [PUB_PATH] [BUNDLE_PATH] [--hub-url URL] [--json] [--force]`
- Mints 32 CSPRNG bytes → 64-hex. Packs `WTF_<NAME>_SECRET` via existing pack path (shared crypto helpers, same bundle format/AADs).
- Prints quoted eval line (`export WTF_<NAME>_SECRET='…'`, shell_quote) + enrollment JSON `{"hub_url":…,"device":…,"key":…}` (JSON-quoted). `--json` → JSON only.
- Refuses to overwrite an existing bundle unless `--force` (footgun guard; pack parity otherwise).
- NOTE: writes through the existing bundle path today; rewires through the vault (Phase 1) at integration.

## Gates

- cargo clippy --all-targets clean; cargo test green (4 existing + new); build --release; cargo audit; stage bin/pqc-secrets.darwin-arm64.
- Sandboxed E2E (subprocess, tmp dirs, sandbox keychain account) + sandbox keychain cleanup after.

## DOX pass

- src/README.md updated (commands + vault rewiring note). Root llms.txt: no structural change → no edit. Re-verified at closeout.

## Rebase integration (post vault-core merge d48ebe3, main 46a62ac)

- Rebased feat/pqc-issuance-transit onto main @ 46a62ac. Conflicts resolved:
  main.rs (union: mod issue + mod vault + both dispatch arms + usage string;
  dropped my redundant pub(crate) edits — vault-core landed the identical
  visibility surface), README.md (vault v1.2.0 bullet + issue/envelope bullet,
  vault-rewiring + TLS notes kept), COMMS ledger (union both entry sets),
  binary (rebuilt + re-staged). Cargo.toml/Cargo.lock/SKILL.md auto-merged
  (vault pinned the same ml-dsa 0.1.1 line).
- Re-gates: clippy --all-targets 0 warnings; cargo test 20/20 (4 shared + 9
  issue + 7 vault); build --release OK; binary re-staged bin/pqc-secrets
  .darwin-arm64 (1522144 B); cargo audit no NEW (allowed anyhow RUSTSEC-2026
  -0190 only); python3 -m unittest discover -s .agents/skills/pqc-secrets
  /tests 14/14 OK; sandboxed E2E 7/7 (E2E_FAIL=0) — same discipline: mktemp
  dirs, PQC_KEYCHAIN_ACCOUNT=pqc-secrets-vtest-issue prefix-form never
  exported, live store + production keychain untouched, sandbox keychain
  entries deleted after. keygen/export steps now carry --use-keychain (no-op
  while no live vault exists; future-proof against vault-first demotion).
- Issuance still writes through the existing bundle path; vault rewiring
  remains the documented followup. SKILL.md merged coherently (vault §2.1 +
  issue §5.9 + envelope §5.10).
