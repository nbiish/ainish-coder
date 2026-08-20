# TASK 2026-08-20 — Python engine → native ML-KEM-768

## Read
- Skill §4: prefer native cryptography.
- Live bundle: engine kyber-py.
- pyca 50.0.0 API verified.

####

## Draft
- keygen kyber-py → expanded 2400B.
- native keygen → seed 64B.
- from_seed_bytes loads seed only.
- expanded import unsupported.
- decap needs private key form.
- pub.encapsulate → (ss, ct).
- ct 1088, ss 32, ek 1184.
- bundle JSON layout unchanged.
- legacy stores must stay readable.
- no-escrow: cannot brick bundles.
- keep kyber-py lazy fallback.
- rotation hint on legacy load.
- engine tag → py-native-mlkem.

####

## Execute
- Added KEM helpers wrapping native.
- cmd_keygen → _kem_keygen.
- pack → _kem_encapsulate.
- decrypt → _kem_decapsulate.
- deps: cryptography>=45.
- SKILL.md engine docs updated.

## Verify
- Fresh dir roundtrip: PASS.
  - keygen → seed store 80B ct.
  - pack 2 keys → export exact.
  - verify PASS, engine tag new.
- Legacy dir (old engine store):
  - 2416B ct expanded form.
  - new engine export PASS.
  - rotation note printed.
- Syntax check PASS.

## Audit
- FIPS 203 ML-KEM-768 only.
- AES-256-GCM unchanged.
- SHA3-256 KDF unchanged.
- No secrets in task file.
- No plaintext key material persisted.
