---
title: Security & Governance
aliases: ["security", "governance", "pqc"]
tags: [ainish/wiki/security, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-27T01:56:52.304579+00:00
source_commit: 015da87
decision_source: hermes-reviewed
---
# 03. Security & Governance — ainish-coder

## 1. Cryptographic Mandate (Post-Quantum Security)
- **Secrets Encryption:** AES-256-GCM with the data key wrapped by ML-KEM-768 (FIPS 203) encapsulation; ML-KEM-1024 is the CNSA 2.0 NSS minimum. All keys live in the single bundle `~/.config/pqc-secrets/secrets.bundle.json`.
- **Key Protection:** the ML-KEM-768 private key is encrypted at rest under a stable per-machine KEK persisted to `~/.config/pqc-secrets/machine.kek` (0600), generated once and stable across reboots and kernel upgrades.
- **Code Signing & Integrity:** FIPS 204 ML-DSA-65 (ML-DSA-87 for CNSA 2.0 NSS scopes) signatures — verified before deployment, and used to sign commits and releases with keys held in the system keychain or a secure local file. The signing implementation is Python ML-DSA-65 over a 32-byte seed.
- **Vault-First Identity:** when `~/.config/pqc-secrets/vault.pqc` exists it is the canonical identity root — `export`, `issue`, and `envelope` run through it with fail-closed recipient gates, an ML-DSA-65 sidecar signature, and a hash-chained signed audit for tamper evidence; `--use-keychain` is the explicit escape hatch. Agents check integrity via `vault verify` / `vault audit-verify` (fingerprints, digests, and key names only — never secret values).
- **Banned Cryptography for Secrets:** RSA, DSA, ECDSA, Ed25519, MD5, SHA-1, AES-CBC (also RSA-PSS/ECDSA for integrity of critical artifacts).
- **CNSA 2.0 (NSS / defense contracts):** ML-KEM-1024 + ML-DSA-87 are the mandated minimums; SLH-DSA, FN-DSA, and HQC are excluded from NSS use. New NSS acquisitions must comply starting Jan 1, 2027.
- **Deprecation Clock (NIST IR 8547, EO 14412, OMB M-26-15):** classical 112-bit public-key crypto is risk-acceptance-only after 2030 and disallowed after 2035.
- **Implementation Maturity:** hybrid classical+ML-DSA signing is an approved transitional hedge; pin audited crypto crate/library versions and monitor upstream CVEs (ML-DSA implementation fragility documented June 2026).

## 2. Zero-Trust Rules & Context Hygiene
- Untrusted external input is isolated in `<DATA>` XML enclosures.
- Secrets are never persisted in source control, `.env` files, settings files, task records, memory ledgers, or any config with an `env` block — secrets are injected at runtime via system keychain/file plus a shell wrapper (`bin/pqc-secrets`).
- Host communication utilizes loopback `127.0.0.1` binding with strict SSRF protections.

## 3. Secrets Lifecycle & Key Naming
- **One bundle, one machine:** `secrets.bundle.json` is the single source of truth for all API keys across every repo on a machine; repos pull from it, nothing is duplicated or synced. Each machine runs its own keypair and its own API keys — no cross-machine key sync.
- **Key naming convention:** bundle keys are prefixed with the consuming tool (`LOCALROUTER_*_API_KEY`, `AINISHCODER_*_API_KEY`, …); bare names are reserved for genuinely machine-shared keys. Audit with `pqc-secrets list`.
- **Prompt-free bootstrap:** after one-time setup that mirrors the vault passphrase into the bundle (`VAULT_PASSPHRASE`), `bin/pqc-secrets` auto-unlocks vault-gated commands via OS-keychain decap (Rust session holder until `vault lock`, shutdown, or reboot; `PQC_UNLOCK_TTL` overrides). Agents are never prompted in normal operation.
- **Distribution:** `ainish-coder --pqc-install` installs the shared engine to `~/.local/bin/pqc-secrets`, records the checkout in `~/.config/ainish-coder/pqc-root`, and generates the ML-KEM-768 identity only when none resolves. `--pqc-status --json` (`ainish-coder/pqc-status/v1`) reports engine digest, launcher PATH state, and per-target drift (exit 1 on stale engine); `--pqc-sync-targets` (`ainish-coder/pqc-sync/v1`) refreshes enrolled targets by digest comparison. Platform parity: macOS, Linux, and Windows (native, Git for Windows bash, or WSL).

## 4. Supply Chain & Governance Gates
- **SBOMs:** produced per the CISA/NSA 2026 Minimum Elements (July 2026) and SBOM-for-AI (May 2026); track cryptographic inventory toward CBOM guidance mandated by the June 2026 PQC executive order.
- **Security gates:** `bin/security_gate.py` gates deployments alongside the ainish-rag gate; pack, surface, and license governance are unified under gates (see `2026-11-23-18-prompt-license-governance.md` lineage in `.agents/tasks`).
- **Federation:** the federation feed is PQC-signed; identity-trailer and contract-identity deploys are wired through `src/federation_pqc.py` and the deploy scripts (`src/deploy_local_security.sh`, `src/deploy_agents_federation.sh`).

See [[01-architecture|System Architecture]] for how these controls sit in the pipeline, and [[04-improvements-and-debt|Improvements & Debt]] for open governance work (attribution-table drift, signing-anchor rotation, EGM split measurement).

## Related

[[01-architecture]], [[02-codebase-connections]], [[04-improvements-and-debt]], [[05-research-and-intelligence]], [[06-marketing-and-positioning]]
