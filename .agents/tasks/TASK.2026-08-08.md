# TASK.2026-08-08 — PQC Security Refresh (Aug 2026)

Worktree: ../ainish-security-refresh
Branch: chore/security-pqc-refresh-2026
Base: develop @ d110694
Date: 2026-08-08

## CoD

Read llms.txt. Main dirty. Stash identified.
New develop. origin/dev fresher. Worktree created.

## Research (Aug 8, 2026)

FIPS 203/204/205 final. 206 draft.
HQC selected. Draft 2026. Final 2027.
SP 800-227 final. Sept 18 2025. Hybrids defined.
IR 8547: 2030 deprecate. 2035 disallow.
EO 14412 June 2026. HVAs PQC by Dec 2030.
OMB M-26-15 aligns agency plans.
CNSA 2.0: ML-KEM-1024, ML-DSA-87 mandatory.
CNSA rejects SLH-DSA, FN-DSA, HQC for NSS.
Jan 2027: new NSS buys need CNSA 2.0.
CISA SBOM 2026 elements July 29 2026.
SBOM-for-AI May 2026. CBOM guidance pending.
OWASP Agentic Top 10 2026: ASI01-ASI10.
OWASP LLM Top 10 2026. Aug 4 2026.
DJB June 2026: ML-DSA impl fragile. Hybrid recommended.
OpenSSL 3.5 PQC March 2026. CMVP ML-DSA March 2026.
RustCrypto ml-kem. No FFI. Type-safe. ml-dsa, slh-dsa.
pyca/cryptography ML-KEM/ML-DSA June 2026.

## Plan

Audit AGENTS.md. Refresh PQC references.
Audit security_gate.py. Update banned algos.
Audit pqc-secrets skill. Sync 2026 state.
Audit llms.txt. CNSA/CBOM note.
Verify no FN-DSA production claim.
Verify SLH-DSA labeled non-CNSA.
Verify ML-KEM-1024 noted for NSS.

pqc-secrets skill. §3 table refactored.
FIPS split per use-case. Status boundary added.
CNSA 2.0 noted. 1024/87 for NSS.
IR 8547 dates added. SP 800-227 cited.
Engine notes updated. fips203 pure-Rust.
kyber-py legacy. pyca native flagged.

production-security skill. FN-DSA relabeled draft.
HQC row added. LMS/XMSS row added.
oqs-provider legacy. OpenSSL 3.5 native.
Hybrid combiners per SP 800-227.
OWASP 2026 sets mapped. ASI01-ASI10.
SBOM 2026 + SBOM-AI + CBOM noted.
DJB fragility hedge documented.

pqc-signatures skill. CNSA 2.0 levels.
OpenSSL 3.5 native. Hybrid hedge.

security_gate.py. 4 → 13 patterns.
EdDSA, MD5, SHA1, CBC, ECB banned.
RSA keygen. P-256 ECDH. IR 8547 guidance.
Verified: 13 regex compile. 6 hits test.
Repo run pre-existing FAIL (docs examples).
12 hits on develop patterns. Not new.
Secret scan clean. Only placeholder `sk-ant-...` doc examples.

llms.txt. CNSA 2.0 + deprecation +
SBOM/CBOM + maturity lines added.

## Merge Hops

1. chore/security-pqc-refresh-2026 → develop (ASK)
2. Integrated develop verify (ASK)
3. develop → main (ASK)
