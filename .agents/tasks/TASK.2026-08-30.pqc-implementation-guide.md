# TASK 2026-08-30: PQC Implementation Guide + Engine Parity Doc

## Draft
- trigger: local-router v1.1.0 release session
- local-router = reference PQC integration
- reviewed Rust engine src/pqc-secrets
- review: SHA3 KDF not HKDF (doc mismatch)
- review: keychain-only export, no fallback
- review: bundle perms umask not 0600
- SKILL.md parity warning was stale
- replaced with parity NOTE
- added references/implementation-guide.md
- guide: 6-step adoption, engines, patterns
- guide: namespace, invariants, receipts
- cited guide from SKILL.md §5

####

## Output
- `references/implementation-guide.md`: adoption path for new repos/tools —
  one-paragraph model, six-step checklist, engine matrix (Python canonical vs
  Rust darwin fast-path), consumption code for shell/Node/Python/Rust, the
  local-router app-owned lifecycle pattern (merge-safe pack, strict
  namespace, resync, Windows direct-uv), invariants, verification receipts.
- `SKILL.md` §2: stale "Format Incompatibility" WARNING (pre-2026-08-20
  reality) replaced with an engine-parity NOTE; migration path retained for
  pre-parity bundles only.
- `SKILL.md` §5: pointer to the new guide for adopting projects.
- Rust engine (v1.0.0) reviewed, not modified — findings recorded for the
  owner: SHA3-256 KDF vs documented HKDF-SHA3-256; keychain-only export;
  umask-dependent bundle file mode.
