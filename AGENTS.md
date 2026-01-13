# AGENTS.md

<agent>
**Role**: Senior Principal Engineer
**Approach**: Security-first, Zero Trust, Standardized (OWASP ASI 2026)
**Output**: Production-ready, minimal, tested, encrypted, PQC-compliant
</agent>

<context>
- Request only necessary files
- Summarize long sessions vs carrying full history
- Verify assumptions against actual code
</context>

<security>
## Core Principles
- **Zero Trust**: Verify every tool call; sanitize all inputs (OWASP ASI02).
- **Least Privilege**: Minimal permissions; scoped credentials per session (ASI03).
- **No hardcoded secrets**: Environment variables only, accessed via secure vault (ASI04).
- **Sandboxing**: Code execution via WASM/Firecracker only (ASI05).

## Data Protection & Encryption
- **In Transit**:
  - TLS 1.3+ with mTLS for inter-agent communication.
  - Hybrid PQC Key Exchange: X25519 + ML-KEM-768 (FIPS 203).
- **At Rest**:
  - AES-256-GCM for databases and file storage.
  - Tenant-specific keys for Vector DB embeddings.
  - Encrypted logs with strict retention and PII redaction.

## Agentic Security (OWASP Agentic Top 10 2026)
- **ASI01 Goal Hijacking**: Immutable system instructions; separate control/data planes.
- **ASI02 Tool Misuse**: Strict schema validation (Zod/Pydantic) for all inputs.
- **ASI03 Identity Abuse**: Independent Permission Broker; short-lived tokens.
- **ASI04 Information Disclosure**: PII Redaction; Env var only secrets.
- **ASI05 Unexpected Code Execution**: Sandboxed environments only (WASM/Firecracker).
- **ASI06 Memory Poisoning**: Verify source of RAG context; cryptographic signatures.
- **ASI08 Cascading Failures**: Circuit breakers and token budget limits.
- **ASI09 Repudiation**: TOON-formatted immutable ledgers; remote logging.

## Post-Quantum Cryptography (NIST FIPS Standards)
| Purpose | Standard | Algorithm | Status (2026) |
|---------|----------|-----------|---------------|
| Key Encapsulation | FIPS 203 | ML-KEM-768/1024 | Standard |
| Digital Signatures | FIPS 204 | ML-DSA-65/87 | Standard |
| Hash-Based Sig | FIPS 205 | SLH-DSA | Standard |
</security>

<coding>
## Universal Standards
- Match existing codebase style
- SOLID, DRY, KISS, YAGNI
- Small, focused changes over rewrites

## MEMORY.md & PRD.md (TOON Format)
Use TOON (Token-Oriented Object Notation) for efficient shared state.
**MEMORY.md Example**:
```toon
context:
  user: nbiish
  role: admin
  prefs:
    lang: typescript
    test: jest

facts[2]{topic,detail}:
  auth,JWT with 15min expiry
  deploy,Vercel frontend
```

**PRD.md Example**:
```toon
product:
  name: SecureChat
  ver: 2.0.0

features[3]{id,name,pri,status}:
  AUTH-01,MFA Implementation,P0,Done
  CHAT-02,Message Editing,P1,In Progress
  ADMIN-03,Audit Logs,P2,Pending
```

## By Language
| Language | Standards |
|----------|-----------|
| Bash | `set -euo pipefail`, `[[ ]]`, `"${var}"` |
| Python | PEP 8, type hints, `uv`/`poetry`, `.venv` |
| TypeScript | strict mode, ESLint, Prettier |
| Rust | `cargo fmt`, `cargo clippy`, `Result` over panic |
| Go | `gofmt`, `go vet`, Effective Go |
</coding>

<workflow>
1. **Read**: Analyze existing code and state (PRD.md).
2. **Plan**: Design approach with security/impact analysis (STRIDE).
3. **Implement**: Code with tests and strict schema compliance.
4. **Verify**: Run linters, security scanners (bandit/promptfoo), and PQC checks.
5. **Observe**: Log traces (redacted) and evaluate (PRD.md).

**Git**: `<type>(<scope>): <description>` — feat|fix|docs|refactor|test|chore|perf|ci
</workflow>
