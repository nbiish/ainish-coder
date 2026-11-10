---
title: "03. Security & Governance"
aliases:
  - "03 Security and Governance"
  - "Security and Governance"
tags:
  - agents/wiki
  - security
  - pqc
generated: true
---

# 03. Security & Governance — ainish-coder-context-prime

## See also

- [[01 Architecture|System Architecture]]
- [[02 Codebase Connections|Codebase Connections and Symbols]]
- [[04 Improvements and Debt|Improvements and Technical Debt]]
- [[05 Research and Intelligence|Research and Intelligence]]
- [[06 Marketing and Positioning|Marketing and Positioning]]
- [[ledger|Operator Ledger]]

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
