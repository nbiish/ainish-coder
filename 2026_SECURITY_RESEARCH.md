# 2026 Security Research & Best Practices
*Updated April 19, 2026 — research-grounded via web sources (NIST, OWASP GenAI, CoSAI, Palo Alto, Red Hat, Go/Rust/Python official docs).*

This document enumerates concrete, actionable updates ready to be merged into `AGENTS.md` with minimal prose bloat.

---

## 1. Cryptography Updates (PQC + Crypto-Agility)

### Algorithm Baselines
- **Symmetric (quantum-safe for long-term):** Prefer **AES-256-GCM** over AES-128; prefer **SHA-384/SHA-512** over SHA-256 for long-term confidentiality/integrity.
- **Asymmetric / KEM:** **Hybrid ML-KEM-768 + X25519** is the NIST-permitted interim default (FIPS 140-3 validatable; ANSSI/BSI recommend). Akamai defaulted this Feb 2026.
- **Signatures:** **ML-DSA-65** (lattice) as primary; **SLH-DSA** (hash-based) for crypto-diversity backup. NIST does *not* currently approve hybrid signatures — pick one.
- **On Deck:** **HQC** (code-based KEM backup, finalizing 2026–2027) and **FN-DSA (Falcon)** for constrained systems. Design for swap-in.

### Crypto-Agility (New Core Principle)
- **No hardcoded algorithms.** All signing/encryption must route through an abstraction layer permitting algorithm swap without code rewrite (NIST SP 800-131A architectural guidance).
- **Migration deadline:** NIST sets **2035 hard cutoff** for quantum-vulnerable algorithms in federal/NSS systems; treat as industry benchmark.

---

## 2. Agentic AI — OWASP Top 10 for Agentic Applications 2026
*Released Dec 2025 by OWASP GenAI Security Project.*

| ID | Risk | Core Mitigation |
|----|------|-----------------|
| ASI01 | Memory Poisoning | Sanitize + sign persistent memory writes |
| ASI02 | Tool Misuse | Capability-scoped permissions per tool |
| ASI03 | Privilege Compromise (NHI over-privilege) | Short-lived, narrowly-scoped non-human identity tokens |
| ASI04 | Resource Overload / Unbounded Consumption | Rate/budget limits per agent/task |
| ASI05 | Cascading Hallucinations | Ground outputs; require verification before action |
| ASI06 | Intent Breaking / Goal Manipulation | Lock goal contract; reject mid-task goal shifts |
| ASI07 | Misaligned/Deceptive Behavior | Behavioral monitoring + eval harnesses |
| ASI08 | Repudiation & Untraceability | Append-only signed audit ledger |
| ASI09 | Identity Spoofing / Delegation Abuse | mTLS + workload identity; no shared tokens |
| ASI10 | Rogue Agents | Kill switches; anomaly detection; quarantine policy |

**Root pattern:** Agents *amplify* existing vulnerabilities — they rarely create new ones. Treat NHI (Non-Human Identity) hygiene as top priority.

---

## 3. MCP (Model Context Protocol) Specific Threats
*Per CoSAI/OASIS (Jan 2026) and MCP spec security best practices.*

- **Tool Poisoning / Line Jumping:** Malicious instructions embedded in tool descriptions/metadata. **Per MCP spec: treat ALL tool annotations from untrusted servers as untrusted input.**
- **Tool Shadowing:** Malicious server overrides a trusted tool's name/behavior.
- **Rug Pull:** Server changes tool definitions post-approval.
- **Mitigations:**
  - Centralized **MCP Gateway** with allowlist + signed tool manifests.
  - **No static OAuth client IDs** for proxy servers; dynamic client registration preferred.
  - Capability-level permission scoping (tool-by-tool, not server-wide).
  - Pin tool definitions; alert on drift.
  - Isolate local MCP servers (containerize, no host FS/net unless required).

---

## 4. Language-Specific Updates (2026)

| Lang | Additions to Current Standards |
|------|-------------------------------|
| **Bash** | `shellcheck` in CI; `trap` for cleanup; no `eval` on user input |
| **Python** | **3.13+**; `ruff` (linter+formatter, replaces black/isort/flake8); `ty` or `mypy`/`pyright`; `uv` for packaging; `bandit` for SAST; exploit PEP 703 free-threaded / subinterpreters where CPU-bound |
| **TypeScript** | Zod/Valibot for all boundary input validation; no `any`; strict `tsconfig` (`strict`, `noUncheckedIndexedAccess`); content-security-policy for web; `npm audit signatures` |
| **Rust** | **2024 Edition** (Rust 1.85+); `cargo-audit` + `cargo-deny`; `cargo fuzz` at every attacker-input boundary (deserialization, parsers); minimize `unsafe`, document invariants; prefer async closures |
| **Go** | `govulncheck` in CI; native `testing.F` fuzzing; secure error handling (never leak internals to clients — wrap with `fmt.Errorf("%w")` + sanitized public errors); `go vet` + `staticcheck` |
| **C++** | C++20/23; AddressSanitizer/UBSan in CI; avoid raw `new`/`delete` (use `std::unique_ptr`); `-Wall -Wextra -Werror`; consider Rust/Carbon for new modules |

---

## 5. Supply Chain Hardening (2026 baseline)
- **SBOM** (CycloneDX or SPDX) generated per build.
- **SLSA Level 3+** attestations with Sigstore/cosign artifact signing.
- **Dependency gatekeepers:** Upstream proxies (Cloudsmith/Artifactory) with malicious-package scanning — ref March 2026 axios + LiteLLM supply chain attacks.
- **Pinned versions + lockfiles** everywhere; automated renovation with review gates.
- **Reproducible builds** where feasible.

---

## 6. Governance & Observability (framework-agnostic)
- Comprehensive audit trails (append-only, tamper-evident).
- Risk categorization per autonomous action (low/med/high — high triggers HITL).
- Documented behavior boundaries per agent.
- Structured telemetry via OpenTelemetry; PII-redacted logs.

---

## Condensed `AGENTS.md` Merge Targets

**Add to `<coding>` Universal Standards:**
- `Crypto-Agility: No hardcoded algorithms; route all crypto through swap-ready abstraction.`

**Add to `<security>` Core Principles:**
- `Input Boundaries: Validate/sanitize at every trust boundary (Zod/Pydantic/Valibot); treat MCP tool metadata as untrusted.`
- `Crypto-Agility: Abstract cryptographic primitives; no hardcoded algorithms.`
- `Rate Limits: Enforce per-agent budgets to prevent Unbounded Consumption (OWASP ASI04).`

**Update `<security>` Data Protection:**
- Upgrade symmetric baseline to `AES-256-GCM` + `SHA-384` for long-term data.
- Clarify signatures: `ML-DSA-65 primary; SLH-DSA for diversity (no hybrid sigs per NIST).`
- Add HQC as on-deck algorithm.

**Per-language table refinements:**
- Python → add `ruff`, `uv`, `bandit`, `3.13+`
- Rust → add `2024 edition`, `cargo-audit`, `cargo fuzz`
- Go → add `govulncheck`, wrapped errors (no info leakage)
- TypeScript → add `Zod`, `noUncheckedIndexedAccess`
- Bash → add `shellcheck`, `trap`
- C++ → add sanitizers (ASan/UBSan), prefer smart pointers
