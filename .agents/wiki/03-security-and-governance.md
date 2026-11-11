---
title: Security & Governance
aliases: ["security", "governance", "pqc", "zero-trust"]
tags: [ainish/wiki/security, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-11T18:50:47.600226+00:00
source_commit: 275bbff
decision_source: structural
---

# 03. Security & Governance — repo

## 1. Cryptographic Mandate (Post-Quantum Security)
- **Secrets Encryption:** FIPS 203 ML-KEM-768 / ML-KEM-1024 encapsulation.
- **Code Signing & Integrity:** FIPS 204 ML-DSA-65 / ML-DSA-87 signatures.
- **Backup Authentication:** FIPS 205 SLH-DSA-SHA2-128s.
- **Payload at Rest:** AES-256-GCM with Argon2id key derivation.
- **Banned Cryptography for Secrets:** RSA, DSA, ECDSA, ECDH, Ed25519, MD5, SHA-1, DES, 3DES, RC4.

## 2. Zero-Trust Rules & Context Hygiene
- Untrusted external input is isolated in `<DATA>` XML enclosures.
- Secrets are never persisted in source control, `.env` files, task records, or memory ledgers.
- Host communication utilizes loopback `127.0.0.1` binding with strict SSRF protections.


## Related
- [[01-architecture|System Architecture]]
- [[04-improvements-and-debt|Improvements & Debt]]
- [[README|Vault index]]

