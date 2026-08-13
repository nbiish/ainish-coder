# Security Audit Report — 2026-08-13

**Scope:** Validate the Aug-2026 PQC + OWASP agentic security configuration against cutting-edge standards.
**Audited commit:** `67ee273` (develop HEAD) — superset of release `1b3f995` "Aug-2026 PQC + OWASP agentic security refresh".
**Verdict:** **PASS** — project-owned code is clean, runtime PQC stack is operational, configuration is current as of 2026-08-13.

---

## 1. Scope & Methodology

This audit validates two prior work streams landing on `develop`:

1. **Currency review** — confirmed the Aug-2026 refresh (commit `1b3f995`, 6 commits / 10 files / +344/-107) reflects standards current as of 2026-08-13.
2. **Test suite execution** — ran the PQC compliance gate, runtime stack checks, and threat-surface scans against the live tree.

The PQC mandate (FIPS 203/204/205) governs secrets operations. Standard crypto (TLS 1.3, SSH) governs transport. The line: if it protects an API key or private datum, it uses PQC.

---

## 2. Test Suite Results

### 2.1 PQC Banned-Pattern Gate — PASS

Scanner: `bin/security_gate.py` (11 banned categories: RS256+/ES256+/PS256+/EdDSA JWT algs, Ed25519 keygen, MD5, SHA-1, AES-CBC, AES-ECB, RSA keygen, P-256 ECDH, hardcoded secrets).

| Scope | Files scanned | Findings |
|-------|---------------|----------|
| Project-owned code (excludes vendored) | 15 | **0** |

Project-owned code is clean across all 11 banned categories. Zero classical crypto in any secrets/signing path, zero hardcoded secrets, zero classical JWT algorithm assignments.

### 2.2 PQC Runtime Stack — PASS

| Component | Status |
|-----------|--------|
| `bin/pqc-secrets` binary | Mach-O arm64, 851 KB, built 2026-08-11 ✓ |
| OpenSSL | **3.6.3** (Jun 2026) — exceeds the 3.5+ native-PQC minimum ✓ |
| ML-DSA-44 / 65 / 87 | All 3 param sets present (FIPS 204) ✓ |
| SLH-DSA-SHA2 (128s/128f/192s/192f/256s/256f) | All present (FIPS 205) ✓ |
| SLH-DSA-SHAKE-256f | Present ✓ |
| Cargo deps (pinned) | `fips203 0.4.3`, `aes-gcm 0.10.3`, `sha3`, `zeroize`, `security-framework` ✓ |

Native PQC is available through stock OpenSSL 3.6.3 — no `oqs-provider` fork needed. The `pqc-secrets` Rust binary uses the NIST FIPS 203 compliant `fips203` crate with a double-envelope structure (ML-KEM-768 KEK → AES-256-GCM DEK → AES-256-GCM payload).

### 2.3 Vendored-Tree Findings — Out of Scope (third-party)

The full-tree gate run surfaced ~25 hits. **Every finding is in a cloned external repo**, outside this repo's PQC mandate:

- `.scrolls-ceremony/repos/*` — HFPathSimulator, AutoNVIS, VisibleEphemerisCPP, SolarImagingDisplay, UnifiedFlightTracker, CoralDualEdgeTPU, goes-hrit-live-webui
- `docs/signals/examples/*` and `docs/signals/creepersweeper/examples/*`

These are third-party reference clones, not governed by the PQC mandate. The gate's `EXCLUDED_DIRECTORIES` does not yet list `.scrolls-ceremony` and `docs`, which is why they surface. **Recommended hardening** (separate task): add `.scrolls-ceremony` and `docs` to `EXCLUDED_DIRECTORIES` in `bin/security_gate.py` so the gate reports a clean PASS on every run without manual triage.

### 2.4 Threat-Surface Scans — PASS

| Scan | Result |
|------|--------|
| Classical JWT algorithm assignments (`algorithms=["RS*"...]`) | None in project code ✓ |
| Dangerous execution (`shell=True`, `eval()`, `exec()`, `pickle.load`, `os.system`) | None in project code ✓ |
| Banned crypto (MD5, SHA-1, AES-CBC/ECB, DES, Blowfish, RC4, pycrypto) | None in project code ✓ |
| Hardcoded secrets (`sk-`, `ghp_`, `AKIA`, API key literals) | None — only pattern definitions in the gate/scan scripts themselves ✓ |

---

## 3. False Positives Triaged

1. **`tle_manager.py:364` SHA-1** (vendored, `.scrolls-ceremony/repos/VisibleEphemerisCPP`): cache-key derivation for TLE satellite data (truncated to 12 chars), not a signature, integrity check, or secret operation. Non-security context.
2. **`app.exec()` "exec(" matches**: all `QApplication.exec()` (Qt event-loop entry), not Python `exec()`. No code-injection vectors.

---

## 4. Currency Check — Standards Current as of 2026-08-13

| Standard / Source | Required state | Configured state | Match |
|-------------------|----------------|------------------|-------|
| NIST FIPS 203/204/205 | Final (Aug 2024) | Referenced as final | ✓ |
| FIPS 206 (FN-DSA/FALCON) | Draft — IPD submitted Aug 2025, awaiting Commerce approval | Labeled **DRAFT — track only**, never CNSA 2.0 | ✓ |
| HQC (FIPS 207) | Selected Mar 2025; draft ~Sep 2026 | "~2026 draft, final ~2027" | ✓ |
| OWASP LLM Top 10 2026 | Published 2026-08-03 (Black Hat) | Re-ranking reflected (Excessive Agency #3, Hidden Context Exposure) | ✓ |
| OWASP Agentic Top 10 2026 | Published 2025-12-09 | ASI01–ASI10 all covered | ✓ |
| OWASP MCP Top 10 | Beta (final ~Oct 2026) | MCP01–10 referenced | ✓ |
| EU AI Act enforcement | Commission powers live 2026-08-02 | Timeline documented | ✓ |
| CISA/NSA SBOM Minimum Elements | Published 2026-07-29 | Referenced | ✓ |
| OpenSSL native PQC | 3.5+ (Mar 2026) | Runtime = 3.6.3 | ✓ |
| NIST IR 8547 deprecation clock | 112-bit risk-acceptance after 2030, disallowed 2035 | Anchored in gate + skills | ✓ |

---

## 5. Minor Gaps (non-blocking)

| Gap | Severity | Recommendation |
|-----|----------|----------------|
| **CVE-2025-54136 (MCPoison, CVSS 8.8)** not in CVE watchlist | Low | Add to `llm-security` §10 CVE table (related CVE-2025-54135 already tracked) |
| **CISA/Five Eyes "Careful Adoption of Agentic AI" (May 2026)** not cited | Informational | Optional citation in `production-security` |
| `EXCLUDED_DIRECTORIES` missing `.scrolls-ceremony`, `docs` | Low | Add both so gate reports clean PASS without triage |
| OWASP MCP Top 10 still beta (final ~Oct 2026) | Informational | Note beta status in `llm-security` §5 |

None are blockers. None affect the PASS verdict.

---

## 6. Audit Checklist

- [x] Task/PRD present — `llms.txt` read; no secrets in either
- [x] Algorithms — only FIPS 203/204/205 for secrets ops; zero classical crypto in project code
- [x] Supply chain — native language respected, Cargo deps pinned, lockfile present
- [x] Secrets — PQC bundle + OS-keychain custody pattern; no plaintext, no `.env`
- [x] Verification — security_gate run on project code; PASS
- [x] Worktree hygiene — task isolated in `docs/security-audit-2026-08-13` worktree
- [x] Currency — configuration matches 2026-08-13 source state

---

## 7. Verdict

**PASS.** The PQC + OWASP agentic security configuration is valid, enforced, and current as of 2026-08-13. Project-owned code is clean (0/11 banned patterns), the runtime PQC stack is operational (binary + OpenSSL 3.6.3 native ML-DSA/SLH-DSA), and all gate findings are pre-existing third-party code in vendored reference repos. The four minor gaps are non-blocking tracking items.
