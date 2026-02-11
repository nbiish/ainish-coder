# AGENTS.md Security Protocol Improvement Recommendations

> **Research Date**: February 11, 2026
> **Scope**: Comprehensive review of AGENTS.md security protocols against current standards and best practices
> **Sources**: NIST CSRC, OWASP GenAI Security Project, NIST Cybersecurity Framework 2.0, NIST IR 8547

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Post-Quantum Cryptography (PQC) Updates](#1-post-quantum-cryptography-pqc-updates)
3. [New NIST Publications & Standards](#2-new-nist-publications--standards)
4. [Zero Trust Architecture Updates](#3-zero-trust-architecture-updates)
5. [OWASP LLM & Agentic AI Security](#4-owasp-llm--agentic-ai-security)
6. [TLS & Transport Security](#5-tls--transport-security)
7. [Encryption at Rest](#6-encryption-at-rest)
8. [AI Agent-Specific Security](#7-ai-agent-specific-security)
9. [Supply Chain Security](#8-supply-chain-security)
10. [NIST Cybersecurity Framework 2.0 Alignment](#9-nist-cybersecurity-framework-20-alignment)
11. [Recommended AGENTS.md Changes](#10-recommended-agentsmd-changes)
12. [Migration Timeline & Priority Matrix](#11-migration-timeline--priority-matrix)

---

## Executive Summary

The current AGENTS.md security section is **well-structured** and already references the correct FIPS 203/204/205 standards. However, several significant developments since the original drafting require updates:

- **FIPS 203/204/205 are now FINAL** (published August 13, 2024) — the current table says "Standard" for 2026 status, which is accurate but should reflect they are already finalized and in active deployment
- **HQC selected as backup KEM** (March 11, 2025) — a second KEM to back up ML-KEM
- **FIPS 206 (FN-DSA/FALCON)** is in draft development — a fourth PQC standard
- **NIST SP 800-227** (September 2025) — new KEM recommendations guidance is now final
- **NIST IR 8547** (November 2024, draft) — formal transition timeline: deprecate quantum-vulnerable algorithms by 2035
- **OWASP Top 10 for Agentic Applications 2026** (December 2025) — directly relevant to this project
- **NIST CSF 2.0** — new Cybersecurity Framework with Cyber AI Profile in development
- **OWASP AIBOM Generator** (December 2025) — AI Bill of Materials tooling
- **EO 14110 on AI was rescinded** (January 20, 2025) — federal AI policy landscape shift

---

## 1. Post-Quantum Cryptography (PQC) Updates

### 1.1 Current AGENTS.md Status (What's There)

```
| Purpose | Standard | Algorithm | Status (2026) |
|---------|----------|-----------|---------------|
| Key Encapsulation | FIPS 203 | ML-KEM-768/1024 | Standard |
| Digital Signatures | FIPS 204 | ML-DSA-65/87 | Standard |
| Hash-Based Sig | FIPS 205 | SLH-DSA | Standard |
```

### 1.2 Recommended Updates

#### Add New Standards to the Table

| Purpose | Standard | Algorithm | Status (Feb 2026) |
|---------|----------|-----------|-------------------|
| Key Encapsulation (Primary) | FIPS 203 | ML-KEM-768/1024 | **Finalized** (Aug 2024) |
| Digital Signatures (Primary) | FIPS 204 | ML-DSA-65/87 | **Finalized** (Aug 2024) |
| Hash-Based Sig (Backup) | FIPS 205 | SLH-DSA | **Finalized** (Aug 2024) |
| Digital Signatures (Backup) | FIPS 206 | FN-DSA (FALCON) | **Draft** (In Development) |
| Key Encapsulation (Backup) | TBD | HQC | **Selected** (Mar 2025), ~2 years to final |
| KEM Guidance | SP 800-227 | N/A | **Finalized** (Sep 2025) |
| Migration Timeline | IR 8547 | N/A | **Draft** (Nov 2024) |

**Key Changes:**
- FIPS 203/204/205 are no longer "upcoming" — they are **final and ready for immediate use**
- NIST explicitly states: _"Go ahead and start using these three."_ (Dustin Moody, PQC project lead)
- HQC was selected over BIKE and Classic McEliece as a backup KEM based on code-based cryptography (different math than ML-KEM's lattice-based approach), providing algorithm diversity
- FN-DSA (FALCON) will provide a lattice-based signature backup with smaller signatures than ML-DSA
- SP 800-227 provides authoritative KEM deployment guidance — should be referenced
- IR 8547 establishes the NIST deprecation timeline for quantum-vulnerable algorithms

#### FIPS 203 Errata Notice (Nov 2025)

NIST identified an issue in FIPS 203 that will be corrected in a future update. Check the errata spreadsheet at:
`https://csrc.nist.gov/files/pubs/fips/203/final/docs/fips-203-potential-updates.xlsx`

#### FIPS 204 Errata Notice (Dec 2025)

Several minor issues identified in FIPS 204. Check:
`https://csrc.nist.gov/files/pubs/fips/204/final/docs/fips-204-potential-updates.xlsx`

### 1.3 Hybrid Key Exchange Update

**Current AGENTS.md**: `X25519 + ML-KEM-768 (FIPS 203)`

**Recommendation**: This is still correct and aligned with best practices. The hybrid approach provides:
- Classical security via X25519 (ECDH)
- Quantum resistance via ML-KEM-768
- Defense-in-depth: if either algorithm is broken, the other still protects

**Additional Consideration**: As HQC becomes standardized (~2027), consider a triple-hybrid option for highest-security contexts:
```
X25519 + ML-KEM-768 + HQC (future)
```

### 1.4 NIST IR 8547 — Transition Timeline

The transition report establishes these key milestones:
- **Now**: Begin migrating to PQC standards immediately
- **2030**: Quantum-vulnerable algorithms should be deprecated for new systems
- **2035**: Quantum-vulnerable algorithms removed from NIST standards entirely
- **High-risk systems**: Must transition much earlier than the general timeline

**Recommendation for AGENTS.md**: Add explicit deprecation targets:
```
Deprecation Timeline (per NIST IR 8547):
- RSA, ECDSA, ECDH: Deprecate by 2030, Remove by 2035
- SHA-1: Already deprecated
- 3DES: Already deprecated
```

---

## 2. New NIST Publications & Standards

### 2.1 NIST SP 800-227 — Recommendations for Key-Encapsulation Mechanisms

**Published**: September 2025 (Final)
**Authors**: Alagic, Barker, Chen, Moody, Robinson, Silberg, Waller

This is the authoritative guide for KEM deployment. It covers:
- KEM definitions and security properties
- Application guidance for ML-KEM
- Key establishment patterns
- Security parameter recommendations

**Action**: Reference SP 800-227 in AGENTS.md security section for KEM implementation guidance.

### 2.2 NIST IR 8545 — Status Report on Fourth Round PQC Standardization

**Published**: March 2025

Documents the selection of HQC and reasoning behind choosing it over BIKE and Classic McEliece. Important for understanding the algorithm diversity strategy.

### 2.3 Additional Digital Signature Schemes — Round 2

NIST continues evaluating additional signature algorithms via the "onramp" process. These are being evaluated for specialized use cases and backup purposes. Monitor:
`https://csrc.nist.gov/projects/pqc-dig-sig/round-2-additional-signatures`

---

## 3. Zero Trust Architecture Updates

### 3.1 Current State

**NIST SP 800-207** (August 2020) remains the foundational Zero Trust document. No revision has been published yet, but supplementary guidance includes:

- **SP 800-207A**: Zero Trust Architecture applied to specific deployment models
- **CSWP 20**: Planning for a Zero Trust Architecture (companion document)

### 3.2 Recommended Enhancements for AGENTS.md

The current AGENTS.md Zero Trust principles are solid. Recommended additions:

#### Add Continuous Verification

```
Zero Trust Enhancement:
- Continuous Authentication: Re-verify identity on every tool call, not just session start
- Risk-Based Access: Adjust permissions dynamically based on behavioral analysis
- Microsegmentation: Each agent capability runs in an isolated security domain
- Assume Breach: Design every component as if adjacent components are compromised
```

#### Add NIST SP 800-207 Reference

```
Reference Standards:
- NIST SP 800-207: Zero Trust Architecture
- NIST SP 800-207A: ZTA Model Deployments
- NIST CSWP 20: Planning for ZTA
```

---

## 4. OWASP LLM & Agentic AI Security

### 4.1 OWASP Top 10 for LLM Applications 2025 (Already in AGENTS_LLM_SECURITY.md)

The current AGENTS_LLM_SECURITY.md already covers the 2025 OWASP LLM Top 10. Verified accurate:

| # | Risk |
|---|------|
| LLM01 | Prompt Injection |
| LLM02 | Sensitive Information Disclosure |
| LLM03 | Supply Chain |
| LLM04 | Data and Model Poisoning |
| LLM05 | Improper Output Handling |
| LLM06 | Excessive Agency |
| LLM07 | System Prompt Leakage |
| LLM08 | Vector and Embedding Weaknesses |
| LLM09 | Misinformation |
| LLM10 | Unbounded Consumption |

### 4.2 NEW: OWASP Top 10 for Agentic Applications 2026

**Published**: December 9, 2025
**Critical Finding**: This is directly relevant to the ainish-coder project.

The OWASP Top 10 for Agentic Applications 2026 is a peer-reviewed framework identifying the most critical security risks facing autonomous and agentic AI systems. Developed by 100+ experts, it provides actionable guidance for securing AI agents that plan, act, and make decisions across complex workflows.

**Recommendation**: This should be referenced in AGENTS.md and AGENTS_LLM_SECURITY.md. The full document should be downloaded and integrated:
`https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/`

### 4.3 NEW: OWASP AIBOM Generator

**Published**: December 2025

AI Bill of Materials (AIBOM) tooling for generating comprehensive manifests of AI system components. Analogous to SBOM but for AI/ML components including:
- Model provenance
- Training data lineage
- Dependency mapping
- Configuration tracking

**Recommendation**: Add AIBOM generation requirement to supply chain security.

### 4.4 NEW: OWASP AI Red Teaming Vendor Evaluation Criteria v1.0

**Published**: February 4, 2026

Criteria for evaluating AI red teaming providers and tooling.

**Recommendation**: Reference for security testing requirements.

---

## 5. TLS & Transport Security

### 5.1 Current AGENTS.md

```
In Transit:
TLS 1.3+ with mTLS for inter-agent communication.
Hybrid PQC Key Exchange: X25519 + ML-KEM-768 (FIPS 203).
```

### 5.2 Recommended Updates

The current specification is aligned with best practices. Enhancements:

#### Add Cipher Suite Specificity

```
TLS 1.3+ Configuration:
- Key Exchange: X25519 + ML-KEM-768 (hybrid PQC per FIPS 203)
- Cipher Suites: TLS_AES_256_GCM_SHA384 (preferred), TLS_CHACHA20_POLY1305_SHA256
- Certificate Signatures: ML-DSA-65 (FIPS 204) for new certificates
- Certificate Management: Automated rotation via ACME protocol
- Certificate Pinning: Enforce for known inter-agent endpoints
- OCSP Stapling: Required for certificate revocation checking
```

#### Add Post-Quantum TLS Guidance

```
PQC TLS Migration:
- Phase 1 (Current): Hybrid X25519+ML-KEM-768 key exchange
- Phase 2 (2027+): Hybrid X25519+ML-KEM-768+HQC once HQC is standardized
- Phase 3 (2030+): Pure PQC key exchange once ecosystem matures
- Certificate Migration: Begin issuing ML-DSA certificates alongside ECDSA
```

---

## 6. Encryption at Rest

### 6.1 Current AGENTS.md

```
At Rest:
AES-256-GCM for databases and file storage.
Tenant-specific keys for Vector DB embeddings.
Encrypted logs with strict retention and PII redaction.
```

### 6.2 Recommended Enhancements

```
At Rest (Enhanced):
- Symmetric Encryption: AES-256-GCM (NIST approved, quantum-resistant at 256-bit)
- Key Derivation: HKDF-SHA384 for deriving per-purpose keys
- Key Wrapping: ML-KEM-768 for key encapsulation (replacing RSA key wrap)
- Tenant Isolation: Per-tenant keys with hardware-backed key storage (HSM/TPM)
- Vector DB: Tenant-specific encryption keys + access control per embedding namespace
- Log Encryption: AES-256-GCM with separate log encryption keys
- Retention Policy: 90-day hot, 365-day cold, crypto-shred on deletion
- PII Handling: Detect-redact-encrypt pipeline before any storage
- Backup Encryption: Independent key hierarchy from primary storage
```

**Note**: AES-256 is considered quantum-resistant (Grover's algorithm reduces effective security to 128-bit equivalent, still adequate). No immediate PQC migration needed for symmetric encryption.

---

## 7. AI Agent-Specific Security

### 7.1 New Section Recommended for AGENTS.md

The current AGENTS.md focuses on general security. Given this project's nature as an AI coding agent toolkit, add agent-specific security:

```
AI Agent Security (per OWASP Agentic Top 10 2026):
- Tool Call Validation: Schema-validate every tool invocation (Zod/Pydantic)
- Capability Boundaries: Agents cannot escalate their own permissions
- Action Audit Trail: Immutable log of every tool call with input/output hashes
- Human-in-the-Loop: Destructive operations require explicit approval
- Sandboxed Execution: Code execution via WASM/containers with resource limits
- Output Sanitization: Never execute or eval agent-generated code directly
- Multi-Agent Trust: mTLS + signed messages between cooperating agents
- Rate Limiting: Per-agent, per-tool, per-session rate limits
- Graceful Degradation: System remains safe if any agent component fails
- Context Isolation: Each agent session has isolated context; no cross-session bleed
```

### 7.2 AIBOM (AI Bill of Materials) Requirement

```
AI Supply Chain:
- Generate AIBOM for all AI components (per OWASP AIBOM standard)
- Track model provenance: source, version, training data lineage
- SLSA Level 3+ for build pipeline integrity
- Sign model artifacts with ML-DSA-65 (FIPS 204)
- Verify model checksums before deployment
```

---

## 8. Supply Chain Security

### 8.1 Current Gap in AGENTS.md

AGENTS.md mentions supply chain indirectly. Recommend explicit coverage:

```
Supply Chain Security:
- SBOM: Generate Software Bill of Materials for all dependencies
- AIBOM: Generate AI Bill of Materials for AI/ML components
- SLSA Level 3+: Build provenance and integrity verification
- Dependency Pinning: Lockfiles mandatory, hash verification on install
- Vulnerability Scanning: Automated CVE scanning in CI/CD pipeline
- Code Signing: All releases signed with ML-DSA-65 (PQC-ready)
- Provenance: Verifiable build provenance for all artifacts
- Vendor Assessment: Third-party model/tool risk assessment per OWASP criteria
```

---

## 9. NIST Cybersecurity Framework 2.0 Alignment

### 9.1 CSF 2.0 Overview

NIST CSF 2.0 is the current cybersecurity framework (published February 2024). Key additions relevant to AGENTS.md:

- **New "Govern" function**: Added to the existing Identify, Protect, Detect, Respond, Recover
- **Supply chain risk management**: Elevated prominence
- **Cybersecurity AI Profile**: In development (workshop held January 14, 2026)
- **Enterprise Risk Management alignment**: NIST IR 8286 series updated December 2025

### 9.2 Recommended Actions

```
CSF 2.0 Alignment:
- Map security controls to CSF 2.0 functions (Govern, Identify, Protect, Detect, Respond, Recover)
- Implement supply chain risk management per CSF 2.0 GV.SC subcategory
- Prepare for Cyber AI Profile integration when finalized
- Reference: NIST CSWP 29 (CSF 2.0)
```

---

## 10. Recommended AGENTS.md Changes

### 10.1 Updated PQC Table

Replace the current PQC table with:

```xml
Post-Quantum Cryptography (NIST FIPS Standards)
| Purpose | Standard | Algorithm | Status (Feb 2026) |
|---------|----------|-----------|-------------------|
| Key Encapsulation (Primary) | FIPS 203 | ML-KEM-768/1024 | Finalized (Aug 2024) |
| Key Encapsulation (Backup) | TBD | HQC | Selected (Mar 2025) |
| Digital Signatures (Primary) | FIPS 204 | ML-DSA-65/87 | Finalized (Aug 2024) |
| Hash-Based Sig (Backup) | FIPS 205 | SLH-DSA | Finalized (Aug 2024) |
| Digital Signatures (Alt) | FIPS 206 | FN-DSA (FALCON) | Draft (In Dev) |
| KEM Guidance | SP 800-227 | — | Finalized (Sep 2025) |
| Migration Timeline | IR 8547 | — | Draft (Nov 2024) |
```

### 10.2 Updated Data Protection Section

```xml
<security>
Core Principles:
Zero Trust: Verify every tool call; sanitize all inputs. (NIST SP 800-207)
Least Privilege: Minimal permissions; scoped credentials per session.
No hardcoded secrets: Environment variables only, accessed via secure vault.
Sandboxing: Code execution via WASM/Firecracker only.
Tool Misuse: Strict schema validation (Zod/Pydantic) for all inputs.
Identity Abuse: Independent Permission Broker; short-lived tokens.
Information Disclosure: PII Redaction; Env var only secrets.
Repudiation: Structured immutable ledgers; remote logging.
Supply Chain: SBOM + AIBOM generation; SLSA Level 3+; dependency pinning.
Agent Safety: OWASP Agentic Top 10 2026 compliance.

Data Protection & Encryption:
In Transit:
TLS 1.3+ with mTLS for inter-agent communication.
Hybrid PQC Key Exchange: X25519 + ML-KEM-768 (FIPS 203).
Cipher Suites: TLS_AES_256_GCM_SHA384 (preferred).
Certificate Signatures: Transition to ML-DSA-65 (FIPS 204).
At Rest:
AES-256-GCM for databases and file storage.
Key Wrapping: ML-KEM-768 for key encapsulation.
Tenant-specific keys for Vector DB embeddings (HSM/TPM-backed).
Encrypted logs with strict retention (90d hot/365d cold) and PII redaction.
Crypto-shred on deletion.

Post-Quantum Cryptography (NIST FIPS Standards)
| Purpose | Standard | Algorithm | Status (Feb 2026) |
|---------|----------|-----------|-------------------|
| Key Encapsulation (Primary) | FIPS 203 | ML-KEM-768/1024 | Finalized |
| Key Encapsulation (Backup) | TBD | HQC | Selected (Mar 2025) |
| Digital Signatures (Primary) | FIPS 204 | ML-DSA-65/87 | Finalized |
| Hash-Based Sig (Backup) | FIPS 205 | SLH-DSA | Finalized |
| Digital Signatures (Alt) | FIPS 206 | FN-DSA (FALCON) | Draft |
| KEM Guidance | SP 800-227 | — | Finalized (Sep 2025) |
| Migration Timeline | IR 8547 | — | Draft (Nov 2024) |

Deprecation Timeline (per NIST IR 8547):
RSA, ECDSA, ECDH → Deprecate by 2030, Remove by 2035.
High-risk systems → Migrate to PQC immediately.

Reference Standards:
NIST SP 800-207 (Zero Trust), SP 800-227 (KEM Guidance),
IR 8547 (PQC Migration), CSF 2.0 (CSWP 29),
OWASP LLM Top 10 2025, OWASP Agentic Top 10 2026
</security>
```

### 10.3 New Section: Agent-Specific Security

Add after the existing `<security>` block:

```xml
<agent_security>
OWASP Compliance:
LLM Top 10 2025: Full mitigation coverage (see AGENTS_LLM_SECURITY.md)
Agentic Top 10 2026: Full mitigation coverage
AIBOM: Generated for all AI components

Tool Call Security:
- Schema-validate every tool invocation
- Immutable audit trail with input/output hashes
- Per-tool rate limiting and resource quotas
- Destructive operations require human approval

Inter-Agent Security:
- mTLS with PQC certificates between agents
- Signed messages using ML-DSA-65 (FIPS 204)
- Context isolation per session
- No cross-session state leakage
</agent_security>
```

---

## 11. Migration Timeline & Priority Matrix

### Priority 1 — Immediate (Do Now)

| Item | Action | Effort |
|------|--------|--------|
| Update PQC table | Reflect finalized status + new standards | Low |
| Add SP 800-227 reference | Link KEM guidance | Low |
| Add IR 8547 reference | Link migration timeline | Low |
| Reference OWASP Agentic Top 10 2026 | New standard directly relevant | Low |
| Fix "Complicated" typo | Line in current AGENTS.md under encryption | Low |

### Priority 2 — Short-Term (Next 30 Days)

| Item | Action | Effort |
|------|--------|--------|
| Add supply chain section | SBOM + AIBOM requirements | Medium |
| Add agent-specific security section | Tool call validation, audit trail | Medium |
| Add CSF 2.0 alignment notes | Governance function mapping | Medium |
| Add deprecation timeline | Per IR 8547 guidance | Low |
| Enhance TLS config | Cipher suite specificity, cert migration plan | Medium |

### Priority 3 — Medium-Term (Next 90 Days)

| Item | Action | Effort |
|------|--------|--------|
| Implement AIBOM generation | Tooling integration | High |
| ML-DSA certificate deployment | Begin issuing PQC certificates | High |
| Monitor FIPS 206 draft | Track FN-DSA standardization | Low |
| Monitor HQC standardization | Track backup KEM progress (~2027) | Low |
| Monitor NIST Cyber AI Profile | Expected to inform CSF + AI alignment | Low |

### Priority 4 — Long-Term (2027+)

| Item | Action | Effort |
|------|--------|--------|
| HQC integration | Add backup KEM once standardized | High |
| FN-DSA integration | Add backup signature once FIPS 206 finalized | Medium |
| Pure PQC transition | Phase out classical-only key exchange | High |
| Full IR 8547 compliance | Complete migration from quantum-vulnerable algorithms | High |

---

## Appendix A: Key URLs & References

| Resource | URL |
|----------|-----|
| NIST PQC Project | https://csrc.nist.gov/projects/post-quantum-cryptography |
| FIPS 203 (ML-KEM) | https://csrc.nist.gov/pubs/fips/203/final |
| FIPS 204 (ML-DSA) | https://csrc.nist.gov/pubs/fips/204/final |
| FIPS 205 (SLH-DSA) | https://csrc.nist.gov/pubs/fips/205/final |
| SP 800-227 (KEM Guidance) | https://csrc.nist.gov/pubs/sp/800/227/final |
| IR 8547 (PQC Migration) | https://csrc.nist.gov/pubs/ir/8547/ipd |
| IR 8545 (Fourth Round Report) | https://csrc.nist.gov/pubs/ir/8545/final |
| HQC Selection Announcement | https://csrc.nist.gov/news/2025/hqc-announced-as-a-4th-round-selection |
| NIST SP 800-207 (Zero Trust) | https://csrc.nist.gov/pubs/sp/800/207/final |
| NIST CSF 2.0 | https://www.nist.gov/cyberframework |
| OWASP LLM Top 10 2025 | https://genai.owasp.org/llm-top-10/ |
| OWASP Agentic Top 10 2026 | https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/ |
| OWASP AIBOM Generator | https://genai.owasp.org/resource/owasp-aibom-generator/ |
| OWASP AI Red Team Criteria | https://genai.owasp.org/resource/owasp-vendor-evaluation-criteria-for-ai-red-teaming-providers-tooling-v1-0/ |
| PQC Additional Signatures | https://csrc.nist.gov/projects/pqc-dig-sig/round-2-additional-signatures |

## Appendix B: Noted Issues in Current AGENTS.md

1. **Typo**: The word "Complicated" appears as a standalone line under "Data Protection & Encryption" → "At Rest" section. Should be removed.
2. **"Crytography" typo**: In the PQC header — should be "Cryptography"
3. **Status column accuracy**: The "Status (2026)" column says "Standard" which is correct but could be more precise: "Finalized (Aug 2024)" to show these are already active, not future.
4. **Missing reference standards**: No NIST publication numbers cited for Zero Trust, CSF, or KEM guidance.
5. **No agent-specific security**: Given this is an AI agent toolkit, the security section should address agentic-specific threats per OWASP Agentic Top 10 2026.
6. **No supply chain section**: No SBOM/AIBOM requirements despite being critical for AI agent deployments.
7. **No deprecation timeline**: Should reference IR 8547 for quantum-vulnerable algorithm phase-out dates.

---

*This document was compiled from authoritative sources (NIST CSRC, OWASP GenAI Security Project) accessed on February 11, 2026. All recommendations should be validated against the latest publications before implementation.*
