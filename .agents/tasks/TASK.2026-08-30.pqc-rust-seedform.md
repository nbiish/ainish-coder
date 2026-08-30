# TASK 2026-08-30 — Rust engine seed-form support (v1.1.0)

## Read
- Live gate failed 05:00Z.
- RUST_EXPORT_BROKEN on seed store.
- fips203 0.4.3: no seed keygen API.
- ml-kem 0.3: FromSeed + decapsulate_slice.
- Python stores sk.hex() keychain.
- Python pub file: raw hex.
- Rust pub file: JSON b64.
- llms.txt PQC mandate read.

####

## Draft
- Keychain material: hex OR b64.
- hex-when-all-hex first, else b64.
- 64B seed → ml-kem from_seed.
- decapsulate_slice on 1088B ct.
- 2400B expanded → fips203 path.
- keygen: random 64B seed, store hex.
- keygen ek bytes → JSON pub (unchanged).
- pack: accept JSON pub OR raw hex.
- fips203 encaps + ml-kem decaps interop test.
- Cargo: ml-kem = 0.3, zeroize.
- version 1.0.0 → 1.1.0.
- dispatcher header comment update.
- SKILL.md engine table update.

####

## Execute
- main.rs: decode_keychain_material().
- main.rs: seed branch in cmd_export.
- main.rs: cmd_keygen seed-form.
- main.rs: load_public_key dual format.
- Cargo.toml: add ml-kem.
- bin/pqc-secrets: header comment.
- SKILL.md + src/README.md notes.

## Verify
- clippy clean; 4/4 tests PASS.
- cargo audit OK (allowed warn).
- Release built; staged to bin/.
- PQC_KEYCHAIN_ACCOUNT override added.
- Sandbox seed-form E2E: SEEDFORM_E2E_OK.
- Live legacy-store export: deferred post-merge (keychain ACL prompt for new ad-hoc signature).
- Live seed migration: deferred post-merge (rollback gates ready).
- Pruned 10 stale .bak.* files; kept rotated-20260830T050012Z pair.

## Audit
- FIPS 203 only; no classical.
- ml-kem pinned, lockfile updated, cargo audit.
- No secrets in task file or commits.
- Verification receipts captured pre-merge.

## Merge
- intent-merge posted; await user confirm.
