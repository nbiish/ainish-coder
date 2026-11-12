# ainish-security refresh — 2026-11-10

**Status:** done. Four parallel research tracks (PQC/libraries, agentic/MCP, supply chain/infra,
governance) against primary sources; every claim dated; deltas applied to
`.agents/skills/ainish-security/` and mirrored byte-identically to
`skills-to-distribute/skills/ainish-security/`.

## What was wrong, not just old

Three claims in the previous text were **incorrect**, not merely stale — worth naming because they
would have misled a reader into a design decision:

1. **"OpenSSL 3.5+ (March 2026) ships native PQC"** — 3.5.0 shipped 2025-04-08. Worse, the OpenSSL
   FIPS provider still has **no validated PQC module** (3.5.8 in CMVP review), so "native" was being
   read as "validated".
2. **"The first CMVP certificate for an ML-DSA module was issued March 2026"** — unsupported. The
   first certificate listing ML-KEM/ML-DSA/SLH-DSA is CMVP #5497 (2026-08).
3. **"FN-DSA (FIPS 206) is draft"** — there is no public draft at all; NIST's Oct-2026 deck still
   says "under development". Same for HQC: selected, no draft.
4. **"ETDI"** appeared as an MCP/OAuth mechanism. It is an academic proposal (arXiv 2506.01333) with
   no spec standing. Removed and marked as research.
5. **EU AI Act high-risk did not start 2026-08-02.** Reg (EU) 2026/1744 moved it to 2027-12-02
   (Annex III) and 2028-08-02 (Annex I). 2026-08-02 brought Art 50 + GPAI enforcement only.

## What was added that did not exist before

- **Empirical MCP risk**: 95 CVEs 2026-08-01 → 2026-11-10, 12 critical; modal causes are
  unauthenticated SSE/HTTP transports and SSRF via OAuth discovery.
- **MCP spec 2026-07-28**: stateless core, `initialize`/`Mcp-Session-Id` removed, DCR → CIMD, EMA
  extension over ID-JAG.
- **Injection-defense consensus**: CaMeL, FIDES/IFC (NeurIPS 2026), and egress control as the only
  layer that holds when the model is fooled.
- **Agent identity as workload identity**: `draft-ietf-wimse-aims`, ID-JAG, transaction tokens; SP
  800-63-4 covers humans only.
- **Implementation-attack posture**: masking alone is insufficient (ePrint 2026/1904), deploy both
  rejection checks (2026/2567), "formally verified" is a scoped claim (2026/192).
- **Signed ≠ trustworthy**: the TanStack/Shai-Hulud compromise carried valid attestations from a
  builder that failed every L3 isolation property.

## Carried forward as UNVERIFIED (do not cite as fact)

NSA FAQ v2.2 body (WAF-blocked), BoringSSL internals, FIPS 206 clearance date, CycloneDX 2.0 ship
date, SPDX 3.1 final, in-toto spec version, any EU adoption of ISO/IEC 42001, and the attribution of
the July-2026 Hugging Face agent-driven intrusion to any specific vendor — HF names no operator.

## Follow-up if this is picked up again

`security-standards-watch` (the Hermes skill) now carries two pitfalls from this pass: verify CMVP
certificates individually rather than trusting vendor prose, and verify that a cited standard exists
before listing it. Next refresh: the HQC draft and FIPS 206 IPD are the two events that would change
the algorithm matrix; EU high-risk harmonised standards remain the bottleneck for the AI Act section.
